class DocusaurusPreviewBuildReconciliationJob < ApplicationJob
  queue_as :default

  DEFAULT_LIMIT = 100
  MAX_LIMIT = 500
  RECHECK_AFTER = 5.minutes

  def perform(limit: DEFAULT_LIMIT)
    return if read_only_maintenance?

    errors = []

    reconciliation_candidates(limit).each do |version|
      reconcile_version(version)
    rescue StandardError => e
      version.mark_preview_build_enqueue_failed!(e)
      Rails.logger.error("Docusaurus preview reconciliation failed version_id=#{version.id}: #{e.class}: #{e.message}")
      errors << e
    ensure
      version.mark_preview_build_reconciled! if version&.persisted?
    end

    raise errors.first if errors.any?
  end

  private

  def reconciliation_candidates(limit)
    normalized_limit = limit.to_i.clamp(1, MAX_LIMIT)
    DocumentVersion
      .markdown_preview_builds
      .where("preview_build_reconciled_at IS NULL OR preview_build_reconciled_at <= ?", RECHECK_AFTER.ago)
      .order(Arel.sql("preview_build_reconciled_at ASC NULLS FIRST"), :id)
      .limit(normalized_limit)
  end

  def reconcile_version(version)
    artifact = DocusaurusPreviewArtifactInstaller.installed_artifact_for(version)
    return if reconcile_installed_artifact(version, artifact)

    case version.preview_build_status.to_sym
    when :preview_not_requested
      enqueue(version)
    when :preview_queued
      enqueue(version, recover_active: true, consume_stale_attempt: true) if version.preview_build_queue_stale?
    when :preview_running
      enqueue(version, recover_active: true) if version.preview_build_running_stale?
    when :preview_failed
      enqueue(version) if version.preview_build_retry_due?
    when :preview_succeeded
      enqueue(version, recover_active: true)
    when :preview_abandoned
      nil
    end
  end

  def reconcile_installed_artifact(version, artifact)
    return false unless artifact
    return true if version.preview_build_artifact_consistent?(artifact)

    version.repair_preview_build_from_artifact!(
      site_path: artifact.site_path,
      artifact_claim_token: artifact.claim_token
    )
  end

  def enqueue(version, recover_active: false, consume_stale_attempt: false)
    DocusaurusPreviewBuildJob.enqueue_for(
      version,
      recover_active:,
      consume_stale_attempt:
    )
  end
end
