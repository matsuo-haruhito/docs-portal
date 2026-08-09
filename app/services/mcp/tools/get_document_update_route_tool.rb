module Mcp
  module Tools
    class GetDocumentUpdateRouteTool < BaseTool
      tool_name "get_document_update_route"
      description "文書の正本を確認し、本文を更新すべきシステムと安全な相関情報を返します。"
      input_schema(properties: { document_public_id: { type: "string" } }, required: ["document_public_id"])
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, document_public_id:, **)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            user = server_context.fetch(:user)
            document = Document.accessible_to(user).includes(:project, :latest_version).find_by!(public_id: document_public_id)
            json_response(document: {
              public_id: document.public_id,
              project_code: document.project.code,
              slug: document.slug,
              source_authority: document.source_authority,
              update_route: update_route(document)
            })
          end
        end

        private

        def update_route(document)
          case document.source_authority
          when "docs_portal"
            { system: "docs-portal", tools: %w[preview_document_revision apply_document_revision check_document_revision preview_document_publish publish_document_revision] }
          when "github"
            source = matching_git_source(document)
            {
              system: "github",
              repository_full_name: source&.repository_full_name,
              branch: source&.branch,
              source_path: document.latest_version&.source_relative_path,
              commit_hash: document.latest_version&.source_commit_hash
            }.compact
          when "sales_mgt"
            mapping = ExternalMasterSyncMapping.find_by(sync_target: document, source_system: "sales-mgt")
            { system: "sales-mgt", source_system: mapping&.source_system, external_id: mapping&.external_id }.compact
          when "external_folder"
            item = document.external_folder_sync_items.includes(:external_folder_sync_source).order(updated_at: :desc).first
            source = item&.external_folder_sync_source
            { system: "external_folder", provider: source&.provider, source_public_id: source&.public_id, path: item&.path }.compact
          end
        end

        def matching_git_source(document)
          path = document.latest_version&.source_relative_path.to_s
          document.project.git_import_sources.detect do |source|
            root = source.normalized_source_path
            path == root || path.start_with?("#{root}/")
          end
        end
      end
    end
  end
end
