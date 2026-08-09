module Mcp
  module Tools
    class PreviewDocumentRevisionTool < BaseTool
      tool_name "preview_document_revision"
      description "docs-portal正本文書の新規作成または本文改訂を検証し、draft作成用の確認tokenを返します。"
      input_schema(
        properties: {
          document_public_id: { type: "string" },
          project_code: { type: "string" },
          title: { type: "string" },
          slug: { type: "string" },
          source_path: { type: "string" },
          body: { type: "string", maxLength: Mcp::DocumentRevision::BODY_MAX_BYTES },
          changelog_summary: { type: "string", maxLength: 1000 },
          metadata: { type: "object" }
        },
        required: ["body"]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, **args)
          with_tool_errors do
            require_scope(server_context, "documents:write")
            require_internal(server_context)
            json_response(Mcp::DocumentRevision.preview(
              user: server_context.fetch(:user),
              application: server_context.fetch(:application),
              attributes: args
            ))
          end
        end
      end
    end
  end
end
