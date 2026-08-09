module Mcp
  module Tools
    class GetProjectAiContextTool < BaseTool
      DOCUMENT_BODY_LIMIT = 20_000
      TOTAL_BODY_LIMIT = 200_000

      tool_name "get_project_ai_context"
      description "案件内の権限付き文書をAIコンテキスト用JSONで取得します。"
      input_schema(
        properties: {
          project_code: { type: "string" },
          mode: { type: "string", enum: %w[compact full] }
        },
        required: ["project_code"]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, project_code:, mode: "compact", **)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            user = server_context.fetch(:user)
            project = Project.accessible_to(user).find_by!(code: project_code)
            payload = AiContextHashExporter.new(project:, viewer: user, mode: mode.to_sym).call.except(:viewer)
            truncate_bodies!(payload) if mode.to_s == "full"
            json_response(payload)
          end
        end

        private

        def truncate_bodies!(payload)
          remaining = TOTAL_BODY_LIMIT
          truncated = false
          payload.fetch(:documents).each do |document|
            body = document[:body_text].to_s
            allowed = [DOCUMENT_BODY_LIMIT, remaining].min.clamp(0, DOCUMENT_BODY_LIMIT)
            included_length = [body.length, allowed].min
            remaining -= included_length
            next if included_length == body.length

            document[:body_text] = body.first(included_length)
            document[:body_truncated] = true
            truncated = true
          end
          payload[:summary][:body_truncated] = truncated
          payload[:summary][:body_character_limit] = TOTAL_BODY_LIMIT
        end
      end
    end
  end
end
