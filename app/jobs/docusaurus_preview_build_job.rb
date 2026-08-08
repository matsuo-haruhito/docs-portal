class DocusaurusPreviewBuildJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(_version_id) { "docusaurus-preview-build" },
      duration: 10.minutes
  end

  class << self
    def enqueue_for(version, recover_active: false, consume_stale_attempt: false)
      queued = version.mark_preview_build_queued!(
        recover_active:,
        consume_stale_attempt:
      )
      return false unless queued

      job = perform_later(version.id)
      raise "Docusaurus preview build could not be enqueued" unless job

      true
    rescue StandardError => e
      version.mark_preview_build_enqueue_failed!(e) if queued
      raise
    end
  end

  def perform(version_id)
    return if read_only_maintenance?

    version = DocumentVersion.find_by(id: version_id)
    return unless version&.markdown_preview_buildable?

    claim_token = version.claim_preview_build!
    return if claim_token.blank?

    archive = DocusaurusPreviewArchiveBuilder.new(version).build
    result = DocusaurusRendererClient.new.build(
      archive_file: archive,
      entry_path: version.source_relative_path
    )

    DocusaurusPreviewArtifactInstaller.new(
      version:,
      archive_path: result.archive_file.path,
      site_path: result.site_path,
      claim_token:
    ).install!
    version.reload.mark_preview_build_succeeded!(claim_token:)
  rescue DocusaurusPreviewArtifactInstaller::StaleClaimError => e
    Rails.logger.info("Skipped stale Docusaurus preview build version_id=#{version_id}: #{e.message}")
  rescue StandardError => e
    version&.mark_preview_build_failed!(e, claim_token:) if claim_token.present?
    raise
  ensure
    result&.archive_file&.close!
    archive&.close!
  end
end
