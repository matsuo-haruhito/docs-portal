module Mcp
  module Tools
    class SearchDocumentsTool < BaseTool
      tool_name "search_documents"
      description "権限内の公開可能文書をキーワード・案件・分類・文書種別で検索します。"
      input_schema(
        properties: {
          q: { type: "string", maxLength: 200 },
          project_code: { type: "string" },
          category: { type: "string", enum: Document.categories.keys },
          document_kind: { type: "string", enum: Document.document_kinds.keys },
          limit: { type: "integer", minimum: 1, maximum: 50 }
        },
        required: []
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, **args)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            user = server_context.fetch(:user)
            scope = Document.portal_visible_to(user).includes(:project, :latest_version)
            scope = scope.joins(:project).where(projects: { code: args[:project_code] }) if args[:project_code].present?
            scope = scope.where(category: args[:category]) if Document.categories.key?(args[:category].to_s)
            scope = scope.where(document_kind: args[:document_kind]) if Document.document_kinds.key?(args[:document_kind].to_s)
            scope = DocumentSearch.new(args[:q].to_s.first(200)).apply(scope)
            documents = scope.distinct.order(updated_at: :desc).limit(normalized_limit(args[:limit]))

            json_response(documents: documents.map { Mcp::DocumentSerializer.call(_1, user:) })
          end
        end
      end
    end
  end
end
