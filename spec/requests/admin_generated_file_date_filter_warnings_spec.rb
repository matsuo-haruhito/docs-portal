require "rails_helper"

RSpec.describe "Admin generated file date filter warnings", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows a warning when a generated file event date filter is invalid" do
    sign_in_as(admin_user)
    create(:generated_file_event, path: "docs/old.yml", scheduled_at: Time.zone.local(2026, 5, 1, 9, 0, 0))
    create(:generated_file_event, path: "docs/new.yml", scheduled_at: Time.zone.local(2026, 5, 10, 9, 0, 0))

    get admin_generated_file_events_path, params: { scheduled_from: "not-a-date" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("日時フィルタを確認してください。")
    expect(page_text).to include("実行予定日(開始)「not-a-date」は日時として解釈できないため、この条件は適用していません。")
    expect(page_text).to include("docs/old.yml")
    expect(page_text).to include("docs/new.yml")
    expect(parsed_html.at_css("input[name='scheduled_from']")&.[]("value")).to eq("not-a-date")
  end

  it "keeps generated file event YYYY-MM-DD filters as beginning and end of day" do
    sign_in_as(admin_user)
    create(:generated_file_event, path: "docs/before.yml", scheduled_at: Time.zone.local(2026, 5, 9, 23, 59, 59))
    create(:generated_file_event, path: "docs/inside-start.yml", scheduled_at: Time.zone.local(2026, 5, 10, 0, 0, 0))
    create(:generated_file_event, path: "docs/inside-end.yml", scheduled_at: Time.zone.local(2026, 5, 10, 23, 59, 59))
    create(:generated_file_event, path: "docs/after.yml", scheduled_at: Time.zone.local(2026, 5, 11, 0, 0, 0))

    get admin_generated_file_events_path, params: { scheduled_from: "2026-05-10", scheduled_to: "2026-05-10" }

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("日時フィルタを確認してください。")
    expect(page_text).to include("docs/inside-start.yml")
    expect(page_text).to include("docs/inside-end.yml")
    expect(page_text).not_to include("docs/before.yml")
    expect(page_text).not_to include("docs/after.yml")
  end

  it "shows a warning when a generated file run date filter is invalid" do
    sign_in_as(admin_user)
    create(:generated_file_run, job_id: "old_job", created_at: Time.zone.local(2026, 5, 1, 9, 0, 0))
    create(:generated_file_run, job_id: "new_job", created_at: Time.zone.local(2026, 5, 10, 9, 0, 0))

    get admin_generated_file_runs_path, params: { created_to: "invalid-date" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("日時フィルタを確認してください。")
    expect(page_text).to include("作成日(終了)「invalid-date」は日時として解釈できないため、この条件は適用していません。")
    expect(page_text).to include("old_job")
    expect(page_text).to include("new_job")
    expect(parsed_html.at_css("input[name='created_to']")&.[]("value")).to eq("invalid-date")
  end

  it "keeps generated file run YYYY-MM-DD filters as beginning and end of day" do
    sign_in_as(admin_user)
    create(:generated_file_run, job_id: "before_job", created_at: Time.zone.local(2026, 5, 9, 23, 59, 59))
    create(:generated_file_run, job_id: "inside_start_job", created_at: Time.zone.local(2026, 5, 10, 0, 0, 0))
    create(:generated_file_run, job_id: "inside_end_job", created_at: Time.zone.local(2026, 5, 10, 23, 59, 59))
    create(:generated_file_run, job_id: "after_job", created_at: Time.zone.local(2026, 5, 11, 0, 0, 0))

    get admin_generated_file_runs_path, params: { created_from: "2026-05-10", created_to: "2026-05-10" }

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("日時フィルタを確認してください。")
    expect(page_text).to include("inside_start_job")
    expect(page_text).to include("inside_end_job")
    expect(page_text).not_to include("before_job")
    expect(page_text).not_to include("after_job")
  end
end