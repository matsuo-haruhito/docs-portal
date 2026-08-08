require "securerandom"

module GeneratedFiles
  class EventDispatchLease
    Claim = Data.define(:group_id, :token, :event_ids, :event_source)

    class StaleClaimError < StandardError; end

    class << self
      def claim!(events, at: Time.current)
        event_ids = Array(events).map(&:id).compact
        return if event_ids.empty?

        GeneratedFileEvent.transaction do
          claimed_events = GeneratedFileEvent
            .where(id: event_ids, status: :pending)
            .order(:scheduled_at, :id)
            .lock("FOR UPDATE SKIP LOCKED")
            .to_a
          next if claimed_events.empty?

          assign_claim!(
            claimed_events,
            group_id: SecureRandom.uuid,
            token: SecureRandom.uuid,
            at:
          )
        end
      end

      def recover_stale_groups!(limit:, at: Time.current, recover_legacy: false)
        normalized_limit = limit.to_i
        return [] unless normalized_limit.positive?

        claims = recover_claimed_stale_groups(limit: normalized_limit, at:)
        remaining = normalized_limit - claims.sum { _1.event_ids.size }
        if recover_legacy && remaining.positive?
          claims.concat(recover_legacy_stale_events(limit: remaining, at:))
        end
        claims
      end

      def events_for(claim)
        events = GeneratedFileEvent
          .where(
            dispatch_group_id: claim.group_id,
            dispatch_claim_token: claim.token,
            status: :processing
          )
          .order(:scheduled_at, :id)
          .to_a
        return [] unless exact_event_set?(events, claim)

        events.index_by(&:id).values_at(*claim.event_ids)
      end

      def with_ownership!(claim)
        owned = false
        result = with_owned_group(claim) do |events|
          owned = true
          block_given? ? yield(events) : true
        end
        raise StaleClaimError, "生成ファイルイベントのdispatch実行権が失効しています。" unless owned

        result
      end

      def heartbeat!(claim, at: Time.current)
        with_owned_group(claim) do |events|
          GeneratedFileEvent.where(id: events.map(&:id)).update_all(
            dispatch_heartbeat_at: at,
            updated_at: at
          )
          true
        end
      end

      def complete!(claim, at: Time.current)
        with_owned_group(claim) do |events|
          GeneratedFileEvent.where(id: events.map(&:id)).update_all(
            status: GeneratedFileEvent.statuses[:processed],
            processed_at: at,
            error_message: nil,
            **cleared_claim_attributes,
            updated_at: at
          )
          true
        end
      end

      def fail!(claim, error:, at: Time.current)
        with_owned_group(claim) do |events|
          GeneratedFileEvent.where(id: events.map(&:id)).update_all(
            status: GeneratedFileEvent.statuses[:failed],
            processed_at: at,
            error_message: error.to_s,
            **cleared_claim_attributes,
            updated_at: at
          )
          true
        end
      end

      private

      def recover_claimed_stale_groups(limit:, at:)
        stale_before = at - GeneratedFileEvent::PROCESSING_STALE_AFTER
        group_ids = GeneratedFileEvent
          .processing
          .where.not(dispatch_group_id: nil)
          .where(
            "COALESCE(dispatch_heartbeat_at, dispatch_claimed_at, updated_at) <= ?",
            stale_before
          )
          .order(Arel.sql("COALESCE(dispatch_heartbeat_at, dispatch_claimed_at, updated_at) ASC"), :id)
          .limit(limit)
          .pluck(:dispatch_group_id)
          .uniq

        group_ids.each_with_object([]) do |group_id, claims|
          claim = rotate_stale_group!(group_id, stale_before:, at:)
          claims << claim if claim
          break claims if claims.sum { _1.event_ids.size } >= limit
        end
      end

      def rotate_stale_group!(group_id, stale_before:, at:)
        GeneratedFileEvent.transaction do
          events = GeneratedFileEvent
            .where(dispatch_group_id: group_id)
            .order(:scheduled_at, :id)
            .lock
            .to_a
          next if events.empty?
          next unless events.all?(&:processing?)

          tokens = events.map(&:dispatch_claim_token).uniq
          next unless tokens.one? && tokens.first.present?

          last_activity_at = events.filter_map do |event|
            event.dispatch_heartbeat_at || event.dispatch_claimed_at || event.updated_at
          end.max
          next unless last_activity_at && last_activity_at <= stale_before

          assign_claim!(events, group_id:, token: SecureRandom.uuid, at:)
        end
      end

      def recover_legacy_stale_events(limit:, at:)
        stale_before = at - GeneratedFileEvent::PROCESSING_STALE_AFTER
        event_ids = GeneratedFileEvent
          .processing
          .where(dispatch_group_id: nil)
          .where("updated_at <= ?", stale_before)
          .order(:updated_at, :id)
          .limit(limit)
          .pluck(:id)

        event_ids.filter_map do |event_id|
          GeneratedFileEvent.transaction do
            event = GeneratedFileEvent.lock.find_by(id: event_id)
            next unless event&.processing?
            next if event.dispatch_group_id.present?
            next unless event.updated_at <= stale_before

            assign_claim!(
              [event],
              group_id: SecureRandom.uuid,
              token: SecureRandom.uuid,
              at:
            )
          end
        end
      end

      def assign_claim!(events, group_id:, token:, at:)
        event_sources = events.map(&:event_source).uniq
        raise ArgumentError, "dispatch group must contain one event source" unless event_sources.one?

        event_ids = events.map(&:id)
        GeneratedFileEvent.where(id: event_ids).update_all(
          status: GeneratedFileEvent.statuses[:processing],
          dispatch_group_id: group_id,
          dispatch_claim_token: token,
          dispatch_claimed_at: at,
          dispatch_heartbeat_at: at,
          processed_at: nil,
          error_message: nil,
          updated_at: at
        )
        Claim.new(
          group_id:,
          token:,
          event_ids:,
          event_source: event_sources.first
        )
      end

      def with_owned_group(claim)
        GeneratedFileEvent.transaction do
          events = GeneratedFileEvent
            .where(dispatch_group_id: claim.group_id)
            .order(:id)
            .lock
            .to_a
          next false unless exact_event_set?(events, claim)
          next false unless events.all?(&:processing?)
          next false unless events.all? { _1.dispatch_claim_token == claim.token }

          yield events
        end
      end

      def exact_event_set?(events, claim)
        events.map(&:id).sort == claim.event_ids.sort
      end

      def cleared_claim_attributes
        {
          dispatch_group_id: nil,
          dispatch_claim_token: nil,
          dispatch_claimed_at: nil,
          dispatch_heartbeat_at: nil
        }
      end
    end
  end
end
