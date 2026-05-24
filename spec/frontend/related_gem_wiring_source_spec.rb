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

  describe "tree_view app-side seam" do
    it "keeps tree rendering anchored in server-rendered helpers and partials" do
      runbook_source = read_source("docs/関連gem連携調査runbook.md")
      sidebar_tree_source = read_source("app/views/documents/_tree.html.erb")
      detail_tree_source = read_source("app/views/projects/_document_detail_tree.html.erb")

      expect(runbook_source).to include("`tree_view` | 文書ツリー / 詳細ツリー / persisted expand state")
      expect(runbook_source).to include("`app/helpers/documents_helper.rb`")
      expect(runbook_source).to include("`app/views/documents/_tree.html.erb`")
      expect(runbook_source).to include("`app/views/projects/_document_detail_tree.html.erb`")
      expect(sidebar_tree_source).to include("<%= tree_view_rows(render_state) %>")
      expect(detail_tree_source).to include("<%= tree_view_rows(render_state) %>")
    end
  end
end
