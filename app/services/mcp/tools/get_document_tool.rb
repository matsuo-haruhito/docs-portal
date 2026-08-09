module Mcp
  module Tools
    class GetDocumentTool < BaseTool
      tool_name "get_document"
      description "権限内の文書詳細と最新版・添付メタデータを取得します。"
      input_schema(
        properties: {
          document_public_id: { type: "string" },
          project_code: { type: "string" },
          slug: { type: "string" }
        },
        required: []
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, **args)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            user = server_context.fetch(:user)
            scope = Document.portal_visible_to(user).includes(:project, latest_version: :document_files)
            document = if args[:document_public_id].present?
              scope.find_by!(public_id: args[:document_public_id])
            elsif args[:project_code].present? && args[:slug].present?
              scope.joins(:project).find_by!(projects: { code: args[:project_code] }, slug: args[:slug])
            else
              raise ArgumentError, "document_public_idまたはproject_codeとslugを指定してください"
            end

            json_response(document: Mcp::DocumentSerializer.call(document, user:, include_files: true))
          end
        end
      end
    end
  end
end
