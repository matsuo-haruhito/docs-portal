class AiContextExportPlan
  Item = Data.define(:document, :document_version, :included, :reason) do
    def included?
      included
    end
  end

  Result = Data.define(:project, :viewer, :items) do
    def included_items
      items.select(&:included?)
    end

    def excluded_items
      items.reject(&:included?)
    end

    def included_documents
      included_items.map(&:document)
    end

    def excluded_documents
      excluded_items.map(&:document)
    end
  end

  def initialize(project:, viewer:, scope: nil)
    @project = project
    @viewer = viewer
    @scope = scope
  end

  def call
    Result.new(project:, viewer:, items: documents.map { item_for(_1) })
  end

  private

  attr_reader :project, :viewer, :scope

  def documents
    @documents ||= (scope || project.documents)
      .includes(:project, :latest_version)
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def item_for(document)
    if document.viewable_by?(viewer)
      Item.new(document:, document_version: document.latest_version, included: true, reason: "viewable")
    else
      Item.new(document:, document_version: document.latest_version, included: false, reason: "not_viewable")
    end
  end
end
