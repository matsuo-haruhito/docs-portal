require "rails_helper"

RSpec.describe "admin document usage reports source" do
  let(:view_source) { Rails.root.join("app/views/admin/document_usage_reports/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/document_usage_reports_helper.rb").read }

  it "uses rails fields kit for project selection" do
    aggregate_failures do
      expect(view_source).to include("form.rfk_select :project_id,")
      expect(view_source).to include("document_usage_report_project_option_label")
      expect(view_source).to include('label: "案件"')
      expect(view_source).to include('placeholder: "案件を選択"')
      expect(view_source).to include('include_blank: "選択してください"')
      expect(view_source).to include("selected: @selected_project&.id")
      expect(view_source).not_to include("form.select :project_id")
    end
  end

  it "wires the report table to rails table preferences" do
    aggregate_failures do
      expect(view_source).to include("table_preferences_editor")
      expect(view_source).to include("table_preferences_table_tag")
      expect(view_source).to include('data-rails-table-preferences-column-key="title"')
      expect(view_source).to include('data-rails-table-preferences-column-key="category"')
      expect(view_source).to include('data-rails-table-preferences-column-key="document_kind"')
      expect(view_source).to include('data-rails-table-preferences-column-key="visibility_policy"')
      expect(view_source).to include('data-rails-table-preferences-column-key="used"')
      expect(view_source).to include('data-rails-table-preferences-column-key="view_count"')
      expect(view_source).to include('data-rails-table-preferences-column-key="download_count"')
      expect(view_source).to include('data-rails-table-preferences-column-key="read_confirmation_count"')
      expect(view_source).to include('data-rails-table-preferences-column-key="last_accessed_at"')
      expect(view_source).to include("project_document_path(@selected_project, row[:slug])")
    end
  end

  it "defines helper metadata for columns and project labels" do
    aggregate_failures do
      expect(helper_source).to include("def document_usage_report_table_columns")
      expect(helper_source).to include("table_preferences_column(:title")
      expect(helper_source).to include("table_preferences_column(:category")
      expect(helper_source).to include("table_preferences_column(:document_kind")
      expect(helper_source).to include("table_preferences_column(:visibility_policy")
      expect(helper_source).to include("table_preferences_column(:used")
      expect(helper_source).to include("table_preferences_column(:view_count")
      expect(helper_source).to include("table_preferences_column(:download_count")
      expect(helper_source).to include("table_preferences_column(:read_confirmation_count")
      expect(helper_source).to include("table_preferences_column(:last_accessed_at")
      expect(helper_source).to include("def document_usage_report_project_option_label(project)")
      expect(helper_source).to include('compact_blank.join(" / ")')
    end
  end
end
