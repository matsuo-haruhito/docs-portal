require "rails_helper"

RSpec.describe "Document approval request search cue", type: :request do
  let(:internal_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  it "shows the server-side query boundary on the search input" do
    sign_in_as(internal_user)

    get document_approval_requests_path

    expect(response).to have_http_status(:ok)
    search_input = parsed_html.at_css("input[name='q']")
    expect(search_input).to be_present
    expect(search_input["maxlength"]).to eq(DocumentApprovalRequestsController::QUERY_MAX_LENGTH.to_s)
    expect(search_input["placeholder"]).to eq("依頼名・本文・文書名・slug・関係者名")
    expect(page_text).to include("検索語は最大#{DocumentApprovalRequestsController::QUERY_MAX_LENGTH}文字です。")
    expect(page_text).to include("依頼名・本文・文書名・slug・関係者名の断片で探せます。")
  end
end
