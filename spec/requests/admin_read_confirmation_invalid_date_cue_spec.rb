require "rails_helper"
require "uri"

RSpec.describe "Admin read confirmation invalid date cue", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:viewer) { create(:user, :external, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  def csv_query
    href = parsed_html.css("a").find { _1.text.squish == "CSV出力" }["href"]
    Rack::Utils.parse_nested_query(URI.parse(href).query)
  end

  it "shows when an invalid start date is excluded while the valid end date is applied" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Later Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "not-a-date", to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("既読確認日時の期間: 指定なし から 2026-05-02 まで")
    expect(page_text).to include("日付として読み取れない開始日は条件から外しています。入力欄の値は確認用に残しています。")
    expect(page_text).to include("表示中: 1件")
    expect(read_confirmation_rows.join).to include("Reader One")
    expect(read_confirmation_rows.join).not_to include("Later Reader")
    expect(parsed_html.at_css("input[name='from']")["value"]).to eq("not-a-date")
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-02")
    expect(csv_query["project_id"]).to eq(project.id.to_s)
    expect(csv_query["to"]).to eq("2026-05-02")
    expect(csv_query).not_to have_key("from")
  end

  it "shows both invalid date fields as excluded without adding a period summary" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "bad-from", to: "bad-to")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("日付として読み取れない開始日・終了日は条件から外しています。入力欄の値は確認用に残しています。")
    expect(page_text).not_to include("既読確認日時の期間:")
    expect(page_text).to include("表示中: 1件")
    expect(read_confirmation_rows.join).to include("Reader One")
    expect(csv_query["project_id"]).to eq(project.id.to_s)
    expect(csv_query).not_to have_key("from")
    expect(csv_query).not_to have_key("to")
  end
end
