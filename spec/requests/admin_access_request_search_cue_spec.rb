require "rails_helper"

RSpec.describe "Admin access request search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows search targets and the query limit near the access request search field" do
    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    form = page.at_css("form[action='#{admin_access_requests_path}']")
    query_input = form.at_css("input[name='q']")
    form_text = form.text.squish

    expect(query_input).to be_present
    expect(query_input["maxlength"]).to eq(Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH.to_s)
    expect(form_text).to include("申請者名 / email、申請ID / 理由、対象名 / code / slug / ファイル名を検索します")
    expect(form_text).to include("最大#{Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH}文字")
    expect(form_text).to include("状態・要求権限・対象種別と組み合わせて絞り込みます")
  end
end
