module Mcp
  module Tools
    class ListProjectsTool < BaseTool
      tool_name "list_projects"
      description "ログイン利用者が参照できる案件を一覧します。"
      input_schema(properties: { limit: { type: "integer", minimum: 1, maximum: 50 } }, required: [])
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, **args)
          with_tool_errors do
            require_scope(server_context, "documents:read")
            user = server_context.fetch(:user)
            scope = Project.accessible_to(user).where(active: true)
            scope = scope.with_portal_visible_documents_for(user) unless user.internal?
            projects = scope.order(:code).limit(normalized_limit(args[:limit]))

            json_response(projects: projects.map { |project|
              {
                public_id: project.public_id,
                code: project.code,
                name: project.name,
                description: project.description,
                document_count: Document.portal_visible_to(user).where(project:).count
              }
            })
          end
        end
      end
    end
  end
end
