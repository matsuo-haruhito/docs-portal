module Mcp
  module Tools
    class BaseTool < ::MCP::Tool
      class << self
        private

        def require_scope(server_context, scope)
          return if server_context.fetch(:scopes).include?(scope)

          throw :mcp_tool_response, error_response("必要なOAuthスコープがありません", code: "insufficient_scope")
        end

        def require_internal(server_context)
          return if server_context.fetch(:user).internal?

          throw :mcp_tool_response, error_response("この操作は社内ユーザーだけが実行できます", code: "forbidden")
        end

        def with_tool_errors
          response = catch(:mcp_tool_response) { yield }
          response
        rescue ActiveRecord::RecordNotFound
          error_response("対象が見つかりません", code: "not_found")
        rescue ApplicationError::Forbidden => e
          error_response(e.message.presence || "この操作を実行する権限がありません", code: "forbidden")
        rescue ApplicationError::BadRequest, ArgumentError => e
          error_response(e.message, code: "invalid_request")
        rescue ActiveRecord::RecordInvalid => e
          error_response(e.record.errors.full_messages.to_sentence, code: "validation_failed")
        end

        def json_response(payload)
          ::MCP::Tool::Response.new([{ type: "text", text: payload.to_json }])
        end

        def error_response(message, code: "error")
          ::MCP::Tool::Response.new(
            [{ type: "text", text: { error: { code:, message: } }.to_json }],
            error: true
          )
        end

        def normalized_limit(value, default: 20, maximum: 50)
          parsed = Integer(value, exception: false) || default
          parsed.clamp(1, maximum)
        end
      end
    end
  end
end
