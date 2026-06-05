require "rails_helper"

RSpec.describe "admin/project_consent_settings admin UI source" do
  let(:form_source) { Rails.root.join("app/views/admin/project_consent_settings/_form.html.slim").read }
  let(:index_source) { Rails.root.join("app/views/admin/project_consent_settings/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/project_consent_settings_helper.rb").read }

  it "uses rails fields kit selects for project and consent term inputs" do
    aggregate_failures do
      expect(form_source).to include("form.rfk_select :project_id")
      expect(form_source).to include("collection_label_method: :name")
      expect(form_source).to include('placeholder: "案件を選択"')
      expect(form_source).to include("form.rfk_select :consent_term_id")
      expect(form_source).to include("project_consent_term_option_label")
      expect(form_source).to include('placeholder: "同意文面を選択"')
    end
  end

  it "uses rails fields kit selects for list project and consent term filters" do
    aggregate_failures do
      expect(index_source).to include("form.rfk_select :project_id")
      expect(index_source).to include("project_consent_setting_project_option_label")
      expect(index_source).to include('placeholder: "案件を選択"')
      expect(index_source).to include('include_blank: "すべて"')
      expect(index_source).to include("selected: @selected_project_id")
      expect(index_source).to include("form.rfk_select :consent_term_id")
      expect(index_source).to include("project_consent_term_option_label")
      expect(index_source).to include('placeholder: "同意文面を選択"')
      expect(index_source).to include("selected: @selected_consent_term_id")
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
      expect(index_source).to include("form.rfk_select :project_id")
      expect(index_source).to include("form.rfk_select :consent_term_id")
      expect(index_source).to include("select_tag :enabled")
      expect(index_source).to include("絞り込み解除")
      expect(index_source).to include("列の表示設定は下の table preferences")
    end
  end

  it "defines helper metadata for the admin table and consent labels" do
    aggregate_failures do
      expect(helper_source).to include("def project_consent_setting_table_columns")
      expect(helper_source).to include("table_preferences_column(:project")
      expect(helper_source).to include("table_preferences_column(:consent_term")
      expect(helper_source).to include("table_preferences_column(:version_label")
      expect(helper_source).to include("def project_consent_setting_project_option_label(project)")
      expect(helper_source).to include('"#{project.name} (#{project.code})"')
      expect(helper_source).to include("def project_consent_term_option_label(term)")
      expect(helper_source).to include('"#{term.title} / #{term.version_label}"')
    end
  end
end
