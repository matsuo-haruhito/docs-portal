module Mcp
  module Tools
    class PublishDocumentRevisionTool < BaseTool
      tool_name "publish_document_revision"
      description "preview済みのdraft版を冪等に公開し、文書の最新版へ指定します。"
      input_schema(
        properties: {
          document_version_public_id: { type: "string" },
          confirmation_token: { type: "string" },
          idempotency_key: { type: "string", minLength: 8, maxLength: 200 }
        },
        required: %w[document_version_public_id confirmation_token idempotency_key]
      )
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, document_version_public_id:, confirmation_token:, idempotency_key:, **)
          with_tool_errors do
            require_scope(server_context, "documents:publish")
            require_internal(server_context)
            json_response(Mcp::DocumentPublish.apply(
              user: server_context.fetch(:user),
              application: server_context.fetch(:application),
              version_public_id: document_version_public_id,
              confirmation_token:,
              idempotency_key:
            ))
          end
        end
      end
    end
  end
end
