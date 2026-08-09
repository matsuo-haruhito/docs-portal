module Mcp
  module Tools
    class ApplyDocumentRevisionTool < BaseTool
      tool_name "apply_document_revision"
      description "preview済み内容から新しいdraft版を冪等に作成します。既存版は変更しません。"
      input_schema(
        properties: {
          confirmation_token: { type: "string" },
          idempotency_key: { type: "string", minLength: 8, maxLength: 200 },
          document_public_id: { type: "string" },
          project_code: { type: "string" },
          title: { type: "string" },
          slug: { type: "string" },
          source_path: { type: "string" },
          body: { type: "string", maxLength: Mcp::DocumentRevision::BODY_MAX_BYTES },
          changelog_summary: { type: "string", maxLength: 1000 },
          metadata: { type: "object" }
        },
        required: %w[confirmation_token idempotency_key body]
      )
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, confirmation_token:, idempotency_key:, **args)
          with_tool_errors do
            require_scope(server_context, "documents:write")
            require_internal(server_context)
            json_response(Mcp::DocumentRevision.apply(
              user: server_context.fetch(:user),
              application: server_context.fetch(:application),
              attributes: args,
              confirmation_token:,
              idempotency_key:
            ))
          end
        end
      end
    end
  end
end
