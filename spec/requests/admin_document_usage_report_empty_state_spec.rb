require "rails_helper"

RSpec.describe "Admin document usage report empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let!(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "explains how to start from the project selection state" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択してください")
    expect(page_text).to include("案件を選択すると集計結果を表示します。")
    expect(page_text).to include("文書名 / slug、利用状況、並び順、期間は、案件を選択した後の集計結果を絞り込む条件です。")
    expect(page_text).to include("CSV出力、表示設定、結果の概要は集計結果の表示後に利用できます。")
    expect(page_text).not_to include("集計サマリ")
    expect(page_text).not_to include("文書利用一覧の表示設定")
  end

  it "returns unreadable project ids to the same guidance without changing filters" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: "999999",
      q: "manual",
      usage_filter: "used",
      sort_order: "last_accessed_desc"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択してください")
    expect(page_text).to include("文書名 / slug、利用状況、並び順、期間は、案件を選択した後の集計結果を絞り込む条件です。")
    expect(parsed_html.at_css("select[name='usage_filter'] option[selected]")["value"]).to eq("used")
    expect(parsed_html.at_css("select[name='sort_order'] option[selected]")["value"]).to eq("last_accessed_desc")
    expect(parsed_html.at_css("input[name='q'][type='search']")["value"]).to eq("manual")
  end
end
