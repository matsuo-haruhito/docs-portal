class DocumentVersionRollback
  MANUAL_UPLOAD_SOURCE = "manual-upload"

  def initialize(version:, actor:)
    @version = version
    @actor = actor
  end

  def call
    Document.transaction do
      document = version.document
      raise ApplicationError::BadRequest, "最新の版だけ取り消せます。" unless document.latest_version_id == version.id
      raise ApplicationError::BadRequest, "手動アップロード版だけ取り消せます。" unless manual_upload_version?

      previous_version = previous_version_for(document)
      version.update!(status: :archived, changelog_summary: rollback_changelog)

      if previous_version
        document.update!(latest_version: previous_version)
      else
        document.update!(latest_version: nil)
        document.archive!(actor: actor)
      end

      previous_version
    end
  end

  private

  attr_reader :version, :actor

  def manual_upload_version?
    version.source_commit_hash == MANUAL_UPLOAD_SOURCE
  end

  def rollback_changelog
    [version.changelog_summary, "Rolled back manual upload at #{Time.current.iso8601}"].compact_blank.join("\n")
  end

  def previous_version_for(document)
    document.document_versions
      .where.not(id: version.id)
      .where(status: DocumentVersion.statuses[:published])
      .order(created_at: :desc, id: :desc)
      .first
  end
end
