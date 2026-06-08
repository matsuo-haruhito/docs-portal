require "rails_helper"

RSpec.describe "Admin document usage report search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let!(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows the query length cue next to the document name and slug search input" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)

    q_input = parsed_html.at_css("input[name='q'][type='search']")
    expect(q_input).to be_present
    expect(q_input["maxlength"]).to eq(Admin::DocumentUsageReportsController::DOCUMENT_USAGE_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("検索語は最大#{Admin::DocumentUsageReportsController::DOCUMENT_USAGE_QUERY_MAX_LENGTH}文字です。")
    expect(page_text).to include("文書名や slug の特徴的な断片で探してください。")
  end
end
