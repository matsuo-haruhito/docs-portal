class ProjectTemplatePlan
  Item = Data.define(:definition, :action, :existing_document) do
    def create?
      action == :create
    end

    def skip?
      action == :skip
    end
  end

  Result = Data.define(:project, :template, :items) do
    def creates
      items.select(&:create?)
    end

    def skips
      items.select(&:skip?)
    end
  end

  def initialize(project:, template: ProjectDocumentTemplate.load("standard_project"))
    @project = project
    @template = template
  end

  def call
    Result.new(project:, template:, items: template.documents.map { item_for(_1) })
  end

  private

  attr_reader :project, :template

  def item_for(definition)
    existing = existing_document_for(definition)
    Item.new(definition:, action: existing.present? ? :skip : :create, existing_document: existing)
  end

  def existing_document_for(definition)
    project.documents.includes(:latest_version).find do |document|
      document.slug == definition.slug || document.latest_version&.source_relative_path == definition.source_path
    end
  end
end
