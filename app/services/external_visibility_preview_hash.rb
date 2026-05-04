class ExternalVisibilityPreviewHash
  def initialize(project:, viewer:, scope: nil)
    @project = project
    @viewer = viewer
    @scope = scope
  end

  def call
    {
      viewer: viewer_hash,
      project: project_hash,
      summary: summary_hash,
      documents: document_hashes
    }
  end

  private

  attr_reader :project, :viewer, :scope

  def documents
    @documents ||= (scope || project.documents)
      .includes(latest_version: :document_files)
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def document_hashes
    @document_hashes ||= documents.map { document_hash(_1) }
  end

  def viewer_hash
    {
      public_id: viewer.public_id,
      email_address: viewer.email_address,
      user_type: viewer.user_type,
      company_id: viewer.company&.public_id
    }
  end

  def project_hash
    {
      public_id: project.public_id,
      code: project.code,
      name: project.name
    }
  end

  def summary_hash
    visible = document_hashes.count { _1[:visible] }
    hidden = document_hashes.size - visible

    {
      total_documents: document_hashes.size,
      visible_documents: visible,
      hidden_documents: hidden,
      downloadable_files: document_hashes.sum { _1[:downloadable_files].size },
      blocked_files: document_hashes.sum { _1[:blocked_files].size }
    }
  end

  def document_hash(document)
    visible = document.viewable_by?(viewer)
    files = document.latest_version&.document_files.to_a
    downloadable_files = visible ? files.select { _1.downloadable_by?(viewer) } : []
    blocked_files = visible ? files.reject { _1.downloadable_by?(viewer) } : files

    {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      visible:,
      project_code: document.project.code,
      latest_version_id: document.latest_version&.public_id,
      downloadable_files: downloadable_files.map { file_hash(_1) },
      blocked_files: blocked_files.map { file_hash(_1) }
    }
  end

  def file_hash(file)
    {
      public_id: file.public_id,
      file_name: file.file_name,
      content_type: file.effective_content_type,
      scan_status: file.scan_status
    }
  end
end
