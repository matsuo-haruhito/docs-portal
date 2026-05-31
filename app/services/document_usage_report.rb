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
    selected_documents = documents

    Result.new(project:, rows: selected_documents.map { row_for(_1) })
  end

  private

  attr_reader :project, :scope, :from, :to

  def documents
    @documents ||= (scope || project.documents).order(:title, :id).to_a
  end

  def row_for(document)
    logs = access_logs_by_document_id.fetch(document.id, [])

    Row.new(
      document:,
      view_count: logs.count(&:view?),
      download_count: logs.count(&:download?),
      read_confirmation_count: read_confirmation_counts_by_document_id.fetch(document.id, 0),
      last_accessed_at: logs.map(&:accessed_at).compact.max
    )
  end

  def access_logs_by_document_id
    @access_logs_by_document_id ||= begin
      return {} if document_ids.empty?

      logs = AccessLog.where(project:, document_id: document_ids)
      logs = logs.where("accessed_at >= ?", from) if from.present?
      logs = logs.where("accessed_at <= ?", to) if to.present?
      logs.select(:document_id, :action_type, :accessed_at).to_a.group_by(&:document_id)
    end
  end

  def read_confirmation_counts_by_document_id
    @read_confirmation_counts_by_document_id ||= begin
      return {} if document_ids.empty?

      confirmations = ReadConfirmation.where(document_id: document_ids)
      confirmations = confirmations.where("confirmed_at >= ?", from) if from.present?
      confirmations = confirmations.where("confirmed_at <= ?", to) if to.present?
      confirmations.group(:document_id).count
    end
  end

  def document_ids
    @document_ids ||= documents.map(&:id).compact
  end
end
