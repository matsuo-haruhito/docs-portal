module Mcp
  module Tools
    class PreviewDocumentPublishTool < BaseTool
      tool_name "preview_document_publish"
      description "品質エラーのないdocs-portal正本draft版について公開内容を確認し、確認tokenを返します。"
      input_schema(properties: { document_version_public_id: { type: "string" } }, required: ["document_version_public_id"])
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, document_version_public_id:, **)
          with_tool_errors do
            require_scope(server_context, "documents:publish")
            require_internal(server_context)
            json_response(Mcp::DocumentPublish.preview(
              user: server_context.fetch(:user),
              application: server_context.fetch(:application),
              version_public_id: document_version_public_id
            ))
          end
        end
      end
    end
  end
end
