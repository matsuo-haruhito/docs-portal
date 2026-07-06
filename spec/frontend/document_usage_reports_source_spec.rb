require "rails_helper"

RSpec.describe "admin document usage reports source" do
  let(:view_source) { Rails.root.join("app/views/admin/document_usage_reports/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/document_usage_reports_helper.rb").read }

  it "uses rails fields kit remote combobox for project selection" do
    aggregate_failures do
      expect(view_source).to include("form.rfk_combobox :project_id,")
      expect(view_source).to include("document_usage_report_project_option_label")
      expect(view_source).to include("document_usage_report_project_selected_option(@selected_project)")
      expect(view_source).to include("project_search_admin_document_usage_reports_path(format: :json)")
      expect(view_source).to include("selected_project_admin_document_usage_reports_path(format: :json)")
      expect(view_source).to include('value_field: "value"')
      expect(view_source).to include('label_field: "text"')
      expect(view_source).to include('search_field: "text"')
      expect(view_source).to include("max_options: Admin::DocumentUsageReportsController::PROJECT_SEARCH_LIMIT")
      expect(view_source).to include('label: "案件"')
      expect(view_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(view_source).to include('include_blank: "選択してください"')
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

  it "keeps usage state cues close to the usage column without changing drill-down link ownership" do
    aggregate_failures do
      expect(view_source).to include("document_usage_report_usage_badge_class(row)")
      expect(view_source).to include("document_usage_report_usage_badge_label(row)")
      expect(view_source).to include("document_usage_report_usage_hint(row)")
      expect(view_source).to include("未利用は期間内の閲覧・ダウンロード・既読確認がない文書")
      expect(view_source).to include("既読のみは閲覧・ダウンロードなしで既読確認だけがある文書")
      expect(view_source).to include("admin_access_logs_path(project_id: @selected_project.id, document_q: row[:slug])")
      expect(view_source).to include("read_confirmation_period_params")
      expect(view_source).to include("admin_read_confirmations_path({ project_id: @selected_project.id, document_slug: row[:slug] }.merge(read_confirmation_period_params))")
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
      expect(helper_source).to include("def document_usage_report_project_selected_option(project)")
      expect(helper_source).to include('compact_blank.join(" / ")')
    end
  end
end
