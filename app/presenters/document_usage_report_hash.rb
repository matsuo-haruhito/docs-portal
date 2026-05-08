class DocumentUsageReportHash
  def initialize(result)
    @result = result
  end

  def call
    {
      project: project_hash,
      summary: summary_hash,
      documents: result.rows.map { row_hash(_1) }
    }
  end

  private

  attr_reader :result

  def project
    result.project
  end

  def project_hash
    {
      public_id: project.public_id,
      code: project.code,
      name: project.name
    }
  end

  def summary_hash
    {
      document_count: result.rows.size,
      used_document_count: result.used_documents.size,
      unused_document_count: result.unused_documents.size,
      total_views: result.total_views,
      total_downloads: result.total_downloads,
      total_read_confirmations: result.total_read_confirmations
    }
  end

  def row_hash(row)
    document = row.document

    {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      category: document.category,
      document_kind: document.document_kind,
      visibility_policy: document.visibility_policy,
      used: row.used?,
      view_count: row.view_count,
      download_count: row.download_count,
      read_confirmation_count: row.read_confirmation_count,
      last_accessed_at: row.last_accessed_at&.iso8601
    }
  end
end
