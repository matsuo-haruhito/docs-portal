require "rails_helper"

RSpec.describe "admin recurring job schedules source" do
  let(:index_source) { Rails.root.join("app/views/admin/recurring_job_schedules/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/recurring_job_schedules_helper.rb").read }

  it "wires the index to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_recurring_job_schedules")
      expect(index_source).to include("admin_recurring_job_schedule_table_columns")
      expect(index_source).to include("rails_table_preference_settings(table_key: table_key)")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "定期ジョブ一覧の表示設定"')
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      job_key
      status
      interval
      next_run_at
      last_enqueued_at
      last_started_at
      last_finished_at
      last_status
      actions
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps the operational controls and return links in the same view" do
    aggregate_failures do
      expect(index_source).to include("sync_definitions_admin_recurring_job_schedules_path")
      expect(index_source).to include("sync_filter_params = { status: @selected_status, enabled: @selected_enabled, q: @selected_query }.compact")
      expect(index_source).to include("params: sync_filter_params")
      expect(index_source).not_to include("admin_recurring_job_schedules_path(sync_definitions: 1)")
      expect(index_source).to include("@schedule_status_options")
      expect(index_source).to include("@selected_status")
      expect(index_source).to include("Triage対象")
      expect(index_source).to include("admin_recurring_job_schedule_path(schedule, return_to: current_list_path)")
      expect(helper_source).to include('label: "前回状態"')
      expect(helper_source).to include("pinned: true")
    end
  end
end
