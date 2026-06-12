require "rails_helper"

RSpec.describe "admin/project_consent_settings admin UI source" do
  let(:form_source) { Rails.root.join("app/views/admin/project_consent_settings/_form.html.slim").read }
  let(:index_source) { Rails.root.join("app/views/admin/project_consent_settings/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/project_consent_settings_helper.rb").read }
  let(:controller_source) { Rails.root.join("app/controllers/admin/project_consent_settings_controller.rb").read }

  it "uses rails fields kit comboboxes for project and consent term inputs" do
    aggregate_failures do
      expect(form_source).to include("form.rfk_combobox :project_id")
      expect(form_source).to include("collection: []")
      expect(form_source).to include("project_consent_setting_project_selected_option")
      expect(form_source).to include("project_search_admin_project_consent_settings_path(format: :json)")
      expect(form_source).to include("selected_project_admin_project_consent_settings_path(format: :json)")
      expect(form_source).to include("Admin::ProjectConsentSettingsController::PROJECT_SEARCH_LIMIT")
      expect(form_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(form_source).to include("form.rfk_combobox :consent_term_id")
      expect(form_source).to include("project_consent_term_selected_option")
      expect(form_source).to include("consent_term_search_admin_project_consent_settings_path(format: :json)")
      expect(form_source).to include("selected_consent_term_admin_project_consent_settings_path(format: :json)")
      expect(form_source).to include("Admin::ProjectConsentSettingsController::CONSENT_TERM_SEARCH_LIMIT")
      expect(form_source).to include('placeholder: "同意文面名・版で検索"')
    end
  end

  it "uses remote comboboxes for list project and consent term filters" do
    aggregate_failures do
      expect(index_source).to include("form.rfk_combobox :project_id")
      expect(index_source).to include("project_consent_setting_project_selected_option(@selected_project)")
      expect(index_source).to include("project_search_admin_project_consent_settings_path(format: :json)")
      expect(index_source).to include("selected_project_admin_project_consent_settings_path(format: :json)")
      expect(index_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(index_source).to include("allow_clear: true")
      expect(index_source).to include("form.rfk_combobox :consent_term_id")
      expect(index_source).to include("project_consent_term_selected_option(@selected_consent_term)")
      expect(index_source).to include("consent_term_search_admin_project_consent_settings_path(format: :json)")
      expect(index_source).to include("selected_consent_term_admin_project_consent_settings_path(format: :json)")
      expect(index_source).to include('placeholder: "同意文面名・版で検索"')
      expect(index_source).not_to include("select_tag :project_id")
      expect(index_source).not_to include("select_tag :consent_term_id")
    end
  end

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('data-rails-table-preferences-column-key="project"')
      expect(index_source).to include('data-rails-table-preferences-column-key="consent_term"')
      expect(index_source).to include('data-rails-table-preferences-column-key="version_label"')
      expect(index_source).to include('data-rails-table-preferences-column-key="required_on"')
      expect(index_source).to include('data-rails-table-preferences-column-key="enabled"')
    end
  end

  it "keeps list filters separate from table preferences" do
    aggregate_failures do
      expect(index_source).to include('class: "filters"')
      expect(index_source).to include("form.rfk_combobox :project_id")
      expect(index_source).to include("form.rfk_combobox :consent_term_id")
      expect(index_source).to include("select_tag :enabled")
      expect(index_source).to include("絞り込み解除")
      expect(index_source).to include("列の表示設定は下の table preferences")
    end
  end

  it "defines helper metadata for the admin table and remote consent labels" do
    aggregate_failures do
      expect(helper_source).to include("def project_consent_setting_table_columns")
      expect(helper_source).to include("table_preferences_column(:project")
      expect(helper_source).to include("table_preferences_column(:consent_term")
      expect(helper_source).to include("table_preferences_column(:version_label")
      expect(helper_source).to include("def project_consent_setting_project_option_label(project)")
      expect(helper_source).to include("def project_consent_setting_project_selected_option(project)")
      expect(helper_source).to include('"#{project.name} (#{project.code})"')
      expect(helper_source).to include("def project_consent_term_option_label(term)")
      expect(helper_source).to include("def project_consent_term_selected_option(term)")
      expect(helper_source).to include('"#{term.title} / #{term.version_label}"')
    end
  end

  it "defines bounded remote search endpoints for project and consent term options" do
    aggregate_failures do
      expect(controller_source).to include("PROJECT_SEARCH_QUERY_MAX_LENGTH = 100")
      expect(controller_source).to include("PROJECT_SEARCH_LIMIT = 20")
      expect(controller_source).to include("CONSENT_TERM_SEARCH_QUERY_MAX_LENGTH = 100")
      expect(controller_source).to include("CONSENT_TERM_SEARCH_LIMIT = 20")
      expect(controller_source).to include("def project_search")
      expect(controller_source).to include("def selected_project")
      expect(controller_source).to include("def consent_term_search")
      expect(controller_source).to include("def selected_consent_term")
      expect(controller_source).to include("scope.exists?(id:) ? id : nil")
    end
  end
end
