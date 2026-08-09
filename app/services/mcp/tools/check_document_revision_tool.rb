module Mcp
  module Tools
    class CheckDocumentRevisionTool < BaseTool
      tool_name "check_document_revision"
      description "draft文書版の品質チェック結果を返します。"
      input_schema(properties: { document_version_public_id: { type: "string" } }, required: ["document_version_public_id"])
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, document_version_public_id:, **)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            require_internal(server_context)
            version = DocumentVersion.includes(:document).find_by!(public_id: document_version_public_id)
            result = DocumentVersionQualityChecker.new(version).call
            json_response(
              document_public_id: version.document.public_id,
              document_version_public_id: version.public_id,
              passed: result.pass?,
              checks: result.checks.map { { key: _1.key, severity: _1.severity, message: _1.message, detail: _1.detail } }
            )
          end
        end
      end
    end
  end
end
