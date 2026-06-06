require "rails_helper"

RSpec.describe "Admin document usage report invalid date cue", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  it "shows which invalid date condition was ignored while keeping valid dates applied" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, from: "not-a-date", to: "2026-05-01")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("無効な日付条件は集計から除外しました: 開始日。")
    expect(page_text).to include("有効な日付条件だけで集計しています。")
    expect(page_text).to include("期間: 2026-05-01 まで")
    expect(page_text).to include("閲覧: 1")
    expect(parsed_html.at_css("input[name='from']")["value"]).to be_blank
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-01")
    expect(csv_export_link["href"]).to include("to=2026-05-01")
    expect(csv_export_link["href"]).not_to include("not-a-date")
    expect(csv_export_link["href"]).not_to include("from=")
  end

  it "shows both ignored date fields when the whole range is invalid" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, from: "2026-13-40", to: "tomorrow")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("無効な日付条件は集計から除外しました: 開始日 / 終了日。")
    expect(page_text).to include("期間: 指定なし（案件全体の累積）")
    expect(parsed_html.at_css("input[name='from']")["value"]).to be_blank
    expect(parsed_html.at_css("input[name='to']")["value"]).to be_blank
    expect(csv_export_link["href"]).not_to include("from=")
    expect(csv_export_link["href"]).not_to include("to=")
  end
end
