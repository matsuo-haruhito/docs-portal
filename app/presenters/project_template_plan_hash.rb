class ProjectTemplatePlanHash
  def initialize(result)
    @result = result
  end

  def call
    {
      project: project_hash,
      template: template_hash,
      summary: summary_hash,
      items: result.items.map { item_hash(_1) }
    }
  end

  private

  attr_reader :result

  def project_hash
    {
      public_id: result.project.public_id,
      code: result.project.code,
      name: result.project.name
    }
  end

  def template_hash
    {
      name: result.template.name,
      description: result.template.description
    }
  end

  def summary_hash
    {
      total: result.items.size,
      create_count: result.creates.size,
      skip_count: result.skips.size
    }
  end

  def item_hash(item)
    definition = item.definition

    {
      action: item.action,
      title: definition.title,
      source_path: definition.source_path,
      slug: definition.slug,
      category: definition.category,
      document_kind: definition.document_kind,
      visibility_policy: definition.visibility_policy,
      existing_document_id: item.existing_document&.public_id
    }
  end
end
