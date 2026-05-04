class ExternalVisibilityPreview
  DocumentResult = Data.define(:document, :visible, :downloadable_files, :blocked_files) do
    def visible?
      visible
    end
  end

  Result = Data.define(:viewer, :project, :document_results) do
    def visible_documents
      document_results.select(&:visible?).map(&:document)
    end

    def hidden_documents
      document_results.reject(&:visible?).map(&:document)
    end

    def downloadable_files
      document_results.flat_map(&:downloadable_files)
    end

    def blocked_files
      document_results.flat_map(&:blocked_files)
    end
  end

  def initialize(project:, viewer:, scope: nil)
    @project = project
    @viewer = viewer
    @scope = scope
  end

  def call
    Result.new(
      viewer:,
      project:,
      document_results: documents.map { preview_document(_1) }
    )
  end

  private

  attr_reader :project, :viewer, :scope

  def documents
    (scope || project.documents)
      .includes(latest_version: :document_files)
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def preview_document(document)
    visible = document.viewable_by?(viewer)
    files = document.latest_version&.document_files.to_a

    DocumentResult.new(
      document:,
      visible:,
      downloadable_files: visible ? files.select { _1.downloadable_by?(viewer) } : [],
      blocked_files: visible ? files.reject { _1.downloadable_by?(viewer) } : files
    )
  end
end
