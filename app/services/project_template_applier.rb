class ProjectTemplateApplier
  Result = Data.define(:plan, :created_documents, :skipped_documents) do
    def created_count
      created_documents.size
    end

    def skipped_count
      skipped_documents.size
    end
  end

  def initialize(project:, template: ProjectDocumentTemplate.load("standard_project"), source_commit_hash: "template")
    @project = project
    @template = template
    @source_commit_hash = source_commit_hash
  end

  def call
    plan = ProjectTemplatePlan.new(project:, template:).call
    created_documents = []

    Document.transaction do
      plan.creates.each do |item|
        created_documents << create_document_from(item.definition)
      end
    end

    Result.new(
      plan:,
      created_documents:,
      skipped_documents: plan.skips.map(&:existing_document)
    )
  end

  private

  attr_reader :project, :template, :source_commit_hash

  def create_document_from(definition)
    document = project.documents.create!(
      title: definition.title,
      slug: unique_slug(definition.slug),
      category: definition.category,
      document_kind: definition.document_kind,
      visibility_policy: definition.visibility_policy
    )

    version = document.document_versions.build(
      version_label: "template",
      source_commit_hash:,
      status: :draft,
      search_body_text: definition.body
    )
    version.assign_source_path_metadata!(source_path: definition.source_path, snapshot_kind: "current")
    version.save!
    document.update!(latest_version: version)

    document
  end

  def unique_slug(base_slug)
    slug = base_slug.presence || "document"
    return slug unless project.documents.exists?(slug:)

    index = 2
    loop do
      candidate = "#{slug}-#{index}"
      return candidate unless project.documents.exists?(slug: candidate)

      index += 1
    end
  end
end
