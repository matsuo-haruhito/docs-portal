require "rails_helper"

RSpec.describe "Related gem wiring source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  describe "Stimulus entrypoint wiring" do
    it "registers related gem controllers on the shared Stimulus application" do
      entrypoint_source = read_source("app/frontend/entrypoints/application.js")

      expect(entrypoint_source).to include('import { RailsTablePreferencesController } from "rails_table_preferences"')
      expect(entrypoint_source).to include('import { TomSelectController } from "rails_fields_kit"')
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')
    end

    it "keeps app-side helper and initializer seams aligned with the registered controllers" do
      fields_kit_initializer = read_source("config/initializers/rails_fields_kit.rb")
      document_sets_form = read_source("app/views/admin/document_sets/_form.html.slim")
      table_preferences_helper = read_source("app/helpers/admin/document_sets_helper.rb")

      expect(fields_kit_initializer).to include('config.controller_name = "rails-fields-kit--tom-select"')
      expect(document_sets_form).to include("= form.rfk_select :project_id,")
      expect(document_sets_form).to include("= form.rfk_select :set_type,")
      expect(document_sets_form).to include("= form.rfk_select :visibility_policy,")
      expect(table_preferences_helper).to include('table_preferences_column(:project')
      expect(table_preferences_helper).to include('table_preferences_column(:actions')
    end
  end

  describe "admin master table preferences seams" do
    it "routes project and user indexes through table preference helpers without changing action links" do
      projects_index = read_source("app/views/admin/projects/index.html.slim")
      users_index = read_source("app/views/admin/users/index.html.slim")
      projects_helper = read_source("app/helpers/admin/projects_helper.rb")
      users_helper = read_source("app/helpers/admin/users_helper.rb")

      aggregate_failures do
        expect(projects_index).to include("- table_key = :admin_projects")
        expect(projects_index).to include("project_table_columns")
        expect(projects_index).to include("table_preferences_editor(")
        expect(projects_index).to include("table_preferences_table_tag(")
        expect(projects_index).to include('data-rails-table-preferences-column-key="code"')
        expect(projects_index).to include('data-rails-table-preferences-column-key="actions"')
        expect(projects_index).to include('edit_link_to "編集"')
        expect(projects_index).to include('delete_link_to "削除"')
        expect(projects_helper).to include('table_preferences_column(:code')
        expect(projects_helper).to include('table_preferences_column(:actions')

        expect(users_index).to include("- table_key = :admin_users")
        expect(users_index).to include("admin_user_table_columns")
        expect(users_index).to include("table_preferences_editor(")
        expect(users_index).to include("table_preferences_table_tag(")
        expect(users_index).to include('data-rails-table-preferences-column-key="email_address"')
        expect(users_index).to include('data-rails-table-preferences-column-key="actions"')
        expect(users_index).to include('edit_link_to "編集"')
        expect(users_index).to include('delete_link_to "削除"')
        expect(users_helper).to include('table_preferences_column(:email_address')
        expect(users_helper).to include('table_preferences_column(:actions')
      end
    end
  end

  describe "Vite alias wiring" do
    it "resolves rails table preferences and rails fields kit entrypoints from gem paths" do
      vite_source = read_source("vite.config.ts")

      expect(vite_source).to include('{ find: /^rails_table_preferences$/, replacement: gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/index.js") }')
      expect(vite_source).to include('{ find: /^rails_table_preferences\\/controller$/, replacement: gemJavaScriptPath("rails_table_preferences", "rails_table_preferences/controller.js") }')
      expect(vite_source).to include('{ find: /^rails_fields_kit$/, replacement: gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/index.js") }')
      expect(vite_source).to include('{ find: /^rails_fields_kit\\/tom_select_controller$/, replacement: gemJavaScriptPath("rails_fields_kit", "rails_fields_kit/tom_select_controller.js") }')
    end

    it "does not treat tree_view as a JavaScript alias dependency" do
      vite_source = read_source("vite.config.ts")

      expect(vite_source).not_to match(/tree_view/i)
    end
  end

  describe "layout asset wiring" do
    it "mounts related gem stylesheets and the shared Vite application entrypoint from the application layout" do
      layout_source = read_source("app/views/layouts/application.html.slim")

      expect(layout_source).to include('= stylesheet_link_tag "tree_view", media: "all"')
      expect(layout_source).to include('= stylesheet_link_tag "rails_table_preferences", media: "all"')
      expect(layout_source).to include("= vite_client_tag")
      expect(layout_source).to include('= vite_javascript_tag "application"')
    end
  end

  describe "tree_view app-side seam" do
    it "keeps tree rendering anchored in server-rendered helpers and partials" do
      runbook_source = read_source("docs/関連gem連携調査runbook.md")
      sidebar_tree_source = read_source("app/views/documents/_tree.html.erb")
      detail_tree_source = read_source("app/views/projects/_document_detail_tree.html.erb")
      projects_helper_source = read_source("app/helpers/projects_helper.rb")

      expect(runbook_source).to include("`tree_view` | 文書ツリー / 詳細ツリー / persisted expand state")
      expect(runbook_source).to include("`app/helpers/documents_helper.rb`")
      expect(runbook_source).to include("`app/views/documents/_tree.html.erb`")
      expect(runbook_source).to include("`app/views/projects/_document_detail_tree.html.erb`")
      expect(sidebar_tree_source).to include("tree_view_rows(render_state")
      expect(detail_tree_source).to include("<%= tree_view_rows(render_state) %>")
      expect(sidebar_tree_source).to include("document_tree_render_state(")
      expect(sidebar_tree_source).to match(/tree_view_rows\(render_state/)
      expect(detail_tree_source).to include("project_document_detail_tree_render_state(")
      expect(detail_tree_source).to match(/tree_view_rows\(render_state/)
      expect(projects_helper_source).to include("TreeView::RenderState.new(")
    end

    it "routes sidebar persisted state keys through DocumentsHelper key generation" do
      controller_source = read_source("app/controllers/projects_controller.rb")

      expect(controller_source).to match(/helpers\.send\(:node_key,\s*project\)/)
      expect(controller_source).to match(/helpers\.send\(\s*:node_key,\s*DocumentsHelper::DocumentTreeFolderNode\.new\(/m)
      expect(controller_source).to include("document_tree_folder_node_key(project, path)")
      expect(controller_source).to include("document_tree_folder_node_key(@project, expanded_source_path)")
      expect(controller_source).to include("document_tree_folder_node_key(@project, collapsed_source_path)")
    end
  end
end
