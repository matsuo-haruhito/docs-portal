require "rails_helper"

RSpec.describe "Related gem wiring source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  describe "Stimulus entrypoint wiring" do
    it "registers related gem controllers on the shared Stimulus application" do
      entrypoint_source = read_source("app/frontend/entrypoints/application.ts")
      table_preferences_controller_source = read_source("app/frontend/controllers/rails_table_preferences_controller.ts")

      expect(entrypoint_source).to include('import RailsTablePreferencesController from "../controllers/rails_table_preferences_controller"')
      expect(table_preferences_controller_source).to include('import { RailsTablePreferencesController as BaseController } from "rails_table_preferences"')
      expect(entrypoint_source).to include('import { TomSelectController as RailsFieldsKitTomSelectController } from "rails_fields_kit"')
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", ExtendedRfkTomSelectController)')
    end

    it "keeps app-side helper and initializer seams aligned with the registered controllers" do
      fields_kit_initializer = read_source("config/initializers/rails_fields_kit.rb")
      document_sets_form = read_source("app/views/admin/document_sets/_form.html.slim")
      table_preferences_helper = read_source("app/helpers/admin/document_sets_helper.rb")

      expect(fields_kit_initializer).to include('config.controller_name = "rails-fields-kit--tom-select"')
      expect(document_sets_form).to include("= form.rfk_combobox :project_id,")
      expect(document_sets_form).to include("= form.rfk_select :set_type,")
      expect(document_sets_form).to include("= form.rfk_select :visibility_policy,")
      expect(table_preferences_helper).to include('table_preferences_column(:project')
      expect(table_preferences_helper).to include('table_preferences_column(:actions')
    end
  end

  describe "admin master table preferences seams" do
    it "routes project and user indexes through table preference helpers while preserving accessible action routes" do
      projects_index = read_source("app/views/admin/projects/index.html.slim")
      users_index = read_source("app/views/admin/users/index.html.slim")
      projects_helper = read_source("app/helpers/admin/projects_helper.rb")
      users_helper = read_source("app/helpers/admin/users_helper.rb")

      aggregate_failures do
        expect(projects_index).to include("- table_key = :admin_projects")
        expect(projects_index).to include("project_table_columns")
        expect(projects_index).to include("render ColumnSettingsComponent.new(")
        expect(projects_index).to include("table_preferences_table_tag(")
        expect(projects_index).to include('data-rails-table-preferences-column-key="code"')
        expect(projects_index).to include('data-rails-table-preferences-column-key="actions"')
        expect(projects_index).to include("link_to edit_admin_project_path(project)")
        expect(projects_index).to include("button_to admin_project_path(project), method: :delete")
        expect(projects_index).to include("i.bi.bi-pencil")
        expect(projects_index).to include("i.bi.bi-trash")
        expect(projects_index).to include("aria: { label: edit_project_cue }, title: edit_project_cue")
        expect(projects_index).to include("aria: { label: delete_project_cue }, title: delete_project_cue")
        expect(projects_helper).to include('table_preferences_column(:code, label: "案件コード", default_width: 150, overflow: :ellipsis, pinned: true)')
        expect(projects_helper).to include('table_preferences_column(:description, label: "説明", default_visible: false, overflow: :ellipsis)')
        expect(projects_helper).to include('table_preferences_column(:actions, label: "操作", default_width: 100, pinned: true)')

        expect(users_index).to include("- table_key = :admin_users")
        expect(users_index).to include("admin_user_table_columns")
        expect(users_index).to include("render ColumnSettingsComponent.new(")
        expect(users_index).to include("table_preferences_table_tag(")
        expect(users_index).to include('data-rails-table-preferences-column-key="email_address"')
        expect(users_index).to include('data-rails-table-preferences-column-key="actions"')
        expect(users_index).to include("link_to edit_admin_user_path(user, return_to: user_return_to)")
        expect(users_index).to include("button_to admin_user_path(user, return_to: user_return_to), method: :delete")
        expect(users_index).to include("i.bi.bi-pencil")
        expect(users_index).to include("i.bi.bi-trash")
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

    it "registers tree_view controllers via the Vite alias and entrypoint" do
      vite_source = read_source("vite.config.ts")
      entrypoint_source = read_source("app/frontend/entrypoints/application.ts")

      expect(vite_source).to include('{ find: /^tree_view$/, replacement: gemJavaScriptPath("tree_view", "tree_view/index.js") }')
      expect(entrypoint_source).to include('import { registerTreeViewControllers } from "tree_view"')
      expect(entrypoint_source).to include("registerTreeViewControllers(application)")
    end
  end

  describe "layout asset wiring" do
    it "mounts related gem stylesheets and the shared Vite application entrypoint from the application layout" do
      layout_source = read_source("app/views/layouts/application.html.slim")

      expect(layout_source).to include('= stylesheet_link_tag "tree_view", media: "all"')
      expect(layout_source).to include('= stylesheet_link_tag "rails_table_preferences", media: "all"')
      expect(layout_source).to include("= vite_client_tag")
      expect(layout_source).to include('= vite_typescript_tag "application"')
    end
  end

  describe "tree_view app-side seam" do
    it "keeps tree rendering anchored in server-rendered helpers and partials" do
      runbook_source = read_source("docs/runbooks/ops/関連gem連携調査runbook.md")
      sidebar_tree_source = read_source("app/views/documents/_tree.html.slim")
      detail_tree_source = read_source("app/views/projects/_document_detail_tree.html.slim")
      projects_helper_source = read_source("app/helpers/projects_helper.rb")

      expect(runbook_source).to include("`tree_view` | 文書ツリー / 詳細ツリー / persisted expand state")
      expect(runbook_source).to include("`app/helpers/documents_helper.rb`")
      expect(runbook_source).to include("`app/views/documents/_tree.html.slim`")
      expect(runbook_source).to include("`app/views/projects/_document_detail_tree.html.slim`")
      expect(sidebar_tree_source).to include("tree_view_rows(render_state")
      expect(detail_tree_source).to include("= tree_view_rows(render_state)")
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
