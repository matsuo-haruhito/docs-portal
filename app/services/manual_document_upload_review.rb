class ManualDocumentUploadReview
  MANUAL_UPLOAD_SOURCE = "manual-upload"

  def initialize(version:, actor:)
    @version = version
    @actor = actor
  end

  def approve!
    Document.transaction do
      ensure_reviewable!
      version.update!(
        status: :published,
        published_at: Time.current,
        published_by_user: actor,
        changelog_summary: [version.changelog_summary, "Approved manual upload at #{Time.current.iso8601}"].compact_blank.join("\n")
      )
      version.document.update!(latest_version: version)
      version
    end
  end

  def reject!
    Document.transaction do
      ensure_reviewable!
      document = version.document
      version.update!(
        status: :archived,
        changelog_summary: [version.changelog_summary, "Rejected manual upload at #{Time.current.iso8601}"].compact_blank.join("\n")
      )
      document.archive!(actor: actor) if document.latest_version.blank? && document.document_versions.published.none?
      document
    end
  end

  private

  attr_reader :version, :actor

  def ensure_reviewable!
    raise ApplicationError::BadRequest, "手動アップロード候補版だけ操作できます。" unless version.source_commit_hash == MANUAL_UPLOAD_SOURCE
    raise ApplicationError::BadRequest, "draftの候補版だけ操作できます。" unless version.draft?
  end
end
