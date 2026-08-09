module Mcp
  class DocumentSerializer
    def self.call(document, user:, include_files: false)
      version = document.latest_version
      version = nil unless version&.viewable_by?(user)

      result = {
        public_id: document.public_id,
        project: {
          public_id: document.project.public_id,
          code: document.project.code,
          name: document.project.name
        },
        title: document.title,
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy,
        importance_level: document.importance_level,
        source_authority: document.source_authority,
        version: version && {
          public_id: version.public_id,
          version_label: version.version_label,
          status: version.status,
          source_commit_hash: version.source_commit_hash,
          source_relative_path: version.source_relative_path,
          published_at: version.published_at&.iso8601
        }
      }

      if include_files
        result[:files] = version ? version.document_files.order(:sort_order, :id).map do |file|
          {
            public_id: file.public_id,
            file_name: file.file_name,
            content_type: file.content_type,
            file_size: file.file_size,
            scan_status: file.scan_status,
            downloadable: file.downloadable_by?(user)
          }
        end : []
      end

      result
    end
  end
end
