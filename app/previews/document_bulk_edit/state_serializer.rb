module DocumentBulkEdit
  class StateSerializer
    def initialize(document)
      @document = document
    end

    def call
      {
        document: {
          id: document.id,
          public_id: document.public_id,
          title: document.title,
          slug: document.slug,
          project_id: document.project_id,
          category: document.category,
          document_kind: document.document_kind,
          visibility_policy: document.visibility_policy,
          importance_level: document.importance_level,
          recommended_sort_order: document.recommended_sort_order,
          retention_until: document.retention_until,
          discard_candidate_at: document.discard_candidate_at,
          archived: document.archived?
        },
        latest_version: serialize_latest_version_state(document.latest_version),
        tag_names: document.document_tags.order(:normalized_name).pluck(:name)
      }
    end

    private

    attr_reader :document

    def serialize_latest_version_state(version)
      return nil if version.blank?

      {
        id: version.id,
        public_id: version.public_id,
        snapshot_kind: version.snapshot_kind,
        published_from: version.published_from,
        published_until: version.published_until
      }
    end
  end
end
