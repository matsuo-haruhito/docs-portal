module ExternalFolderSync
  class RunLease
    PENDING_LEASE_DURATION = ExternalFolderSyncWebhookEvent::DELIVERY_STALE_AFTER
    RUNNING_LEASE_DURATION = 1.hour
    STALE_RUN_ERROR_MESSAGE = "外部フォルダ同期の実行権が期限切れになったため、再処理待ちへ戻しました。"

    class Error < StandardError; end
    class BusyError < Error; end
    class StaleClaimError < Error; end

    class << self
      def reserve!(source:, mode:, at: Time.current, recover_stale: false)
        run = nil

        source.with_lock do
          source.reload
          normalize_owner_locked!(source, at:, recover_stale:)
          return nil if source.active_sync_run_id.present? || legacy_active_run?(source)

          run = source.external_folder_sync_runs.create!(
            mode:,
            status: :pending,
            enqueued_at: at
          )
          source.update!(
            active_sync_run: run,
            sync_lease_expires_at: at + PENDING_LEASE_DURATION
          )

          next unless block_given?
          next if yield(run)

          source.update!(active_sync_run: nil, sync_lease_expires_at: nil)
          run.destroy!
          run = nil
        end

        run
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def claim!(run, at: Time.current)
        source = run.external_folder_sync_source
        claimed = false

        source.with_lock do
          run.lock!
          source.reload
          next unless current_owner?(source, run)
          next unless run.pending?
          next if block_given? && !yield(run)

          run.update!(
            status: :running,
            started_at: at,
            heartbeat_at: at
          )
          source.update!(sync_lease_expires_at: at + RUNNING_LEASE_DURATION)
          claimed = true
        end

        claimed
      end

      def heartbeat!(run, at: Time.current)
        with_ownership!(run, at:) { true }
      end

      def with_ownership!(run, at: Time.current)
        source = run.external_folder_sync_source
        result = nil

        source.with_lock do
          run.lock!
          source.reload
          verify_ownership!(source, run)
          run.update!(heartbeat_at: at)
          source.update!(sync_lease_expires_at: at + RUNNING_LEASE_DURATION)
          result = block_given? ? yield : true
        end

        result
      end

      def complete!(run, run_attributes:, source_attributes: {}, at: Time.current)
        source = run.external_folder_sync_source

        source.with_lock do
          run.lock!
          source.reload
          verify_ownership!(source, run)
          run.update!(run_attributes.merge(finished_at: run_attributes[:finished_at] || at))
          source.update!(source_attributes.merge(active_sync_run: nil, sync_lease_expires_at: nil))
        end

        run
      end

      def fail!(run, error:, restore_webhook_events: false, at: Time.current)
        source = run.external_folder_sync_source
        failed = false

        source.with_lock do
          run.lock!
          source.reload
          next unless current_owner?(source, run)
          next unless run.pending? || run.running?

          run.update!(status: :failed, finished_at: at, error_message: error.to_s)
          restore_webhook_events_locked!(run) if restore_webhook_events
          source.update!(
            active_sync_run: nil,
            sync_lease_expires_at: nil,
            last_error_message: error.to_s
          )
          failed = true
        end

        failed
      end

      def recover_stale_sources!(limit:, at: Time.current)
        source_ids = ExternalFolderSyncSource
          .where.not(active_sync_run_id: nil)
          .where(sync_lease_expires_at: ..at)
          .order(:sync_lease_expires_at, :id)
          .limit(limit)
          .pluck(:id)

        source_ids.count do |source_id|
          source = ExternalFolderSyncSource.find_by(id: source_id)
          source && recover_stale_source!(source, at:)
        end
      end

      def recover_stale_source!(source, at: Time.current)
        recovered = false

        source.with_lock do
          source.reload
          recovered = recover_stale_owner_locked!(source, at:)
        end

        recovered
      end

      private

      def normalize_owner_locked!(source, at:, recover_stale:)
        owner = current_owner_run(source)
        owner ||= adopt_legacy_owner_locked!(source, at:) if recover_stale
        return unless owner

        if owner.pending? || owner.running?
          if recover_stale && (source.sync_lease_expires_at.blank? || source.sync_lease_expires_at <= at)
            recover_stale_owner_locked!(source, at:)
          end
        else
          source.update!(active_sync_run: nil, sync_lease_expires_at: nil)
        end
      end

      def adopt_legacy_owner_locked!(source, at:)
        owner = legacy_active_run(source)
        return unless owner

        source.update!(
          active_sync_run: owner,
          sync_lease_expires_at: lease_expiry(owner, at:)
        )
        owner
      end

      def legacy_active_run?(source)
        legacy_active_run(source).present?
      end

      def legacy_active_run(source)
        source.external_folder_sync_runs.where(status: %i[pending running]).order(:id).first
      end

      def lease_expiry(run, at:)
        if run.pending?
          (run.enqueued_at || run.created_at || at) + PENDING_LEASE_DURATION
        else
          (run.heartbeat_at || run.updated_at || run.started_at || at) + RUNNING_LEASE_DURATION
        end
      end

      def recover_stale_owner_locked!(source, at:)
        run = current_owner_run(source)
        return false unless run
        return false unless source.sync_lease_expires_at.blank? || source.sync_lease_expires_at <= at

        run.lock!
        source.reload
        return false unless current_owner?(source, run)
        return false unless source.sync_lease_expires_at.blank? || source.sync_lease_expires_at <= at

        if run.pending? || run.running?
          run.update!(status: :failed, finished_at: at, error_message: STALE_RUN_ERROR_MESSAGE)
          restore_webhook_events_locked!(run)
        end
        source.update!(active_sync_run: nil, sync_lease_expires_at: nil, last_error_message: STALE_RUN_ERROR_MESSAGE)
        true
      end

      def restore_webhook_events_locked!(run)
        run.external_folder_sync_webhook_events
          .where(status: %i[enqueued processing])
          .update_all(
            status: ExternalFolderSyncWebhookEvent.statuses[:received],
            external_folder_sync_run_id: nil,
            error_message: ExternalFolderSyncWebhookEvent::STALE_DELIVERY_RECOVERED_ERROR_MESSAGE,
            updated_at: Time.current
          )
      end

      def verify_ownership!(source, run)
        return if current_owner?(source, run) && run.running?

        raise StaleClaimError, "外部フォルダ同期の実行権が失効しています。"
      end

      def current_owner?(source, run)
        source.active_sync_run_id == run.id
      end

      def current_owner_run(source)
        return unless source.active_sync_run_id

        ExternalFolderSyncRun.find_by(id: source.active_sync_run_id)
      end
    end
  end
end
