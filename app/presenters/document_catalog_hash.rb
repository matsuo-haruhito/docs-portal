class DocumentCatalogHash
  def initialize(document_catalog:, viewer:)
    @document_catalog = document_catalog
    @viewer = viewer
  end

  def call
    {
      catalog: catalog_hash,
      viewer: viewer_hash,
      summary: summary_hash,
      items: visible_items.map { item_hash(_1) }
    }
  end

  private

  attr_reader :document_catalog, :viewer

  def visible_items
    @visible_items ||= document_catalog.visible_items_for(viewer)
  end

  def catalog_hash
    {
      public_id: document_catalog.public_id,
      name: document_catalog.name,
      description: document_catalog.description,
      audience_type: document_catalog.audience_type,
      visibility_policy: document_catalog.visibility_policy,
      project_code: document_catalog.project.code
    }
  end

  def viewer_hash
    return nil if viewer.blank?

    {
      public_id: viewer.public_id,
      user_type: viewer.user_type,
      company_id: viewer.company&.public_id
    }
  end

  def summary_hash
    {
      total_items: document_catalog.document_catalog_items.count,
      visible_items: visible_items.size,
      hidden_items: document_catalog.document_catalog_items.count - visible_items.size
    }
  end

  def item_hash(item)
    document = item.document
    version = document.latest_version

    {
      sort_order: item.sort_order,
      note: item.note,
      document: {
        public_id: document.public_id,
        title: document.title,
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy,
        latest_version_id: version&.public_id
      }
    }
  end
end
