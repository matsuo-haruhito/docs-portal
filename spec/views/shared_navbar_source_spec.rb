require "rails_helper"

RSpec.describe "shared navbar source" do
  def navbar_source
    Rails.root.join("app/views/shared/_navbar.html.slim").read
  end

  def source_line(marker)
    navbar_source.lines.find { |line| line.include?(marker) }
  end

  it "keeps representative admin operation routes attached to the management menu cue" do
    aggregate_failures do
      active_line = source_line("admin_nav_active =")
      label_line = source_line("admin_nav_label =")

      expect(active_line).to include("admin_generated_file_runs_path")
      expect(active_line).to include("admin_generated_file_events_path")
      expect(active_line).to include("admin_recurring_job_schedules_path")
      expect(label_line).to include('["生成ファイル実行履歴", admin_generated_file_runs_path]')
      expect(label_line).to include('["生成ファイルイベント", admin_generated_file_events_path]')
      expect(label_line).to include('["定期ジョブ", admin_recurring_job_schedules_path]')
    end
  end

  it "keeps representative integration operation routes attached to the integration menu cue" do
    aggregate_failures do
      active_line = source_line("integration_nav_active =")
      label_line = source_line("integration_nav_label =")

      expect(active_line).to include("admin_webhook_deliveries_path")
      expect(active_line).to include("admin_file_upload_dry_runs_path")
      expect(label_line).to include('["Webhook送信履歴", admin_webhook_deliveries_path]')
      expect(label_line).to include('["単体ファイルdry-run", admin_file_upload_dry_runs_path]')
    end
  end

  it "keeps the admin-only dropdown boundary in the shared navbar" do
    aggregate_failures do
      expect(navbar_source).to include("- if admin_user?")
      expect(navbar_source).to include("| 管理メニュー")
      expect(navbar_source).to include("| 連携メニュー")
    end
  end
end
