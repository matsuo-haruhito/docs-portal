require "rails_helper"

RSpec.describe "admin recurring job schedules status presentation" do
  let(:index_view) do
    Rails.root.join("app/views/admin/recurring_job_schedules/index.html.slim").read
  end

  let(:show_view) do
    Rails.root.join("app/views/admin/recurring_job_schedules/show.html.slim").read
  end

  let(:helper_source) do
    Rails.root.join("app/helpers/admin/recurring_job_schedules_helper.rb").read
  end

  let(:locale_source) do
    Rails.root.join("config/locales/recurring_jobs.ja.yml").read
  end

  it "renders recurring job statuses through helper badges" do
    aggregate_failures do
      expect(index_view).to include("td = recurring_job_status_badge(schedule.last_status)")
      expect(show_view).to include("dd = recurring_job_status_badge(@schedule.last_status)")
      expect(show_view).to include("td = recurring_job_status_badge(run.status)")
      expect(index_view).not_to include('td = schedule.last_status.presence || "-"')
      expect(show_view).not_to include('dd = @schedule.last_status.presence || "-"')
      expect(show_view).not_to include("td = run.status")
    end
  end

  it "defines localized recurring job status labels and tones" do
    aggregate_failures do
      expect(helper_source).to include("def recurring_job_status_badge")
      expect(helper_source).to include('localized_label("recurring_jobs.status", value)')
      expect(helper_source).to include('value.presence || "not_run"')
      expect(helper_source).to include('when "failed"')
      expect(helper_source).to include('when "running"')
      expect(helper_source).to include('when "completed"')
      expect(locale_source).to include("recurring_jobs:")
      expect(locale_source).to include('not_run: "未実行"')
      expect(locale_source).to include('enqueued: "キュー待ち"')
      expect(locale_source).to include('completed: "完了"')
    end
  end
end
