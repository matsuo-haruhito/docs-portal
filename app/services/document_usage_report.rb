class DocumentUsageReport
  Row = Data.define(:document, :view_count, :download_count, :read_confirmation_count, :last_accessed_at) do
    def used?
      view_count.positive? || download_count.positive? || read_confirmation_count.positive?
    end
  end

  Result = Data.define(:project, :rows) do
    def used_documents
      rows.select(&:used?).map(&:document)
    end

    def unused_documents
      rows.reject(&:used?).map(&:document)
    end

    def total_views
      rows.sum(&:view_count)
    end

    def total_downloads
      rows.sum(&:download_count)
    end

    def total_read_confirmations
      rows.sum(&:read_confirmation_count)
    end
  end

  def initialize(project:, scope: nil, from: nil, to: nil)
    @project = project
    @scope = scope
    @from = from
    @to = to
  end

  def call
    Result.new(project:, rows: documents.map { row_for(_1) })
  end

  private

  attr_reader :project, :scope, :from, :to

  def documents
    @documents ||= (scope || project.documents).order(:title, :id).to_a
  end

  def row_for(document)
    logs = access_logs_for(document)

    Row.new(
      document:,
      view_count: logs.count(&:view?),
      download_count: logs.count(&:download?),
      read_confirmation_count: read_confirmations_for(document).count,
      last_accessed_at: logs.map(&:accessed_at).compact.max
    )
  end

  def access_logs_for(document)
    logs = AccessLog.where(project:, document:)
    logs = logs.where("accessed_at >= ?", from) if from.present?
    logs = logs.where("accessed_at <= ?", to) if to.present?
    logs.to_a
  end

  def read_confirmations_for(document)
    confirmations = ReadConfirmation.where(document:)
    confirmations = confirmations.where("confirmed_at >= ?", from) if from.present?
    confirmations = confirmations.where("confirmed_at <= ?", to) if to.present?
    confirmations
  end
end
