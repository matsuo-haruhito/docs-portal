class DocumentVersionRollback
  def initialize(version:, actor:)
    @version = version
    @actor = actor
  end

  def call
    Document.transaction do
      document = version.document
      raise ApplicationError::BadRequest, "最新の版だけ取り消せます。" unless document.latest_version_id == version.id

      previous_version = previous_version_for(document)
      version.destroy!

      if previous_version
        document.update!(latest_version: previous_version)
      else
        document.archive!(actor: actor)
      end

      previous_version
    end
  end

  private

  attr_reader :version, :actor

  def previous_version_for(document)
    document.document_versions
      .where.not(id: version.id)
      .order(created_at: :desc, id: :desc)
      .first
  end
end
