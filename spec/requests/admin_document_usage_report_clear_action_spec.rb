require "rails_helper"

RSpec.describe "Admin document usage report clear action", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def top_clear_link
    parsed_html.css("a[href='#{admin_document_usage_reports_path}']").find do |link|
      link.text.squish == "すべての条件をクリア"
    end
  end

  before do
    project
    sign_in_as(admin_user)
  end

  it "hides the top clear action before a clearable condition exists" do
    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると集計結果を表示します。")
    expect(top_clear_link).to be_nil

    get admin_document_usage_reports_path(usage_filter: "all", sort_order: "title")

    expect(response).to have_http_status(:ok)
    expect(top_clear_link).to be_nil
  end

  it "shows the top clear action when project or filter conditions are present" do
    clearable_params = [
      { project_id: project.id },
      { q: "manual" },
      { usage_filter: "used" },
      { sort_order: "last_accessed_desc" },
      { from: "2026-05-01" },
      { to: "2026-05-02" },
      { from: "not-a-date" }
    ]

    clearable_params.each do |params|
      get admin_document_usage_reports_path(params)

      expect(response).to have_http_status(:ok)
      expect(top_clear_link).to be_present
    end

    expect(page_text).to include("無効な日付条件は集計から除外しました")
  end
end
