class ProjectDocumentTemplate
  DocumentDefinition = Data.define(:source_path, :title, :category, :document_kind, :visibility_policy, :body) do
    def slug
      source_path.to_s.parameterize.presence || File.basename(source_path.to_s, File.extname(source_path.to_s)).parameterize
    end
  end

  attr_reader :name, :description, :documents

  def self.load(name)
    path = Rails.root.join("config", "document_templates", "#{name}.yml")
    raise ArgumentError, "template not found: #{name}" unless path.exist?

    new(YAML.safe_load_file(path, permitted_classes: [], aliases: false))
  end

  def initialize(attributes)
    @name = attributes.fetch("name")
    @description = attributes["description"]
    @documents = attributes.fetch("documents").map { document_definition(_1) }
  end

  private

  def document_definition(attributes)
    DocumentDefinition.new(
      source_path: attributes.fetch("source_path"),
      title: attributes.fetch("title"),
      category: attributes.fetch("category", "other"),
      document_kind: attributes.fetch("document_kind", "markdown"),
      visibility_policy: attributes.fetch("visibility_policy", "internal_only"),
      body: attributes.fetch("body", "")
    )
  end
end
