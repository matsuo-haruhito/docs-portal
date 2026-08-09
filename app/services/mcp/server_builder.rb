module Mcp
  class ServerBuilder
    TOOLS = [
      Mcp::Tools::ListProjectsTool,
      Mcp::Tools::SearchDocumentsTool,
      Mcp::Tools::GetDocumentTool,
      Mcp::Tools::GetProjectAiContextTool,
      Mcp::Tools::GetDocumentUpdateRouteTool,
      Mcp::Tools::PreviewDocumentRevisionTool,
      Mcp::Tools::ApplyDocumentRevisionTool,
      Mcp::Tools::CheckDocumentRevisionTool,
      Mcp::Tools::PreviewDocumentPublishTool,
      Mcp::Tools::PublishDocumentRevisionTool
    ].freeze

    def self.build(user:, application:, scopes:)
      ::MCP::Server.new(
        name: "docs-portal",
        version: "1.0.0",
        instructions: "案件文書を権限と正本区分に従って参照・改訂します。外部正本文書は更新先handoffに従ってください。",
        tools: TOOLS,
        server_context: { user:, application:, scopes: }
      )
    end
  end
end
