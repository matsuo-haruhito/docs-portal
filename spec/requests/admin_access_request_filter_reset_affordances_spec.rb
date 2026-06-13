require "rails_helper"

RSpec.describe "Admin access request filter reset affordances", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user: requester)
    sign_in_as(admin_user)
  end

  it "hides the form clear action until a real filter is active" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(filter_form.css("a").map { |link| link.text.squish }).not_to include("条件をクリア")
  end

  it "keeps filter reset actions near both the form and filtered empty state" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)

    get admin_access_requests_path(q: "does-not-match")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する申請はありません。")
    expect(page_text).to include("検索: does-not-match")

    clear_link = filter_form.css("a[href='#{admin_access_requests_path}']").find { |link| link.text.squish == "条件をクリア" }
    expect(clear_link).to be_present

    reset_link = parsed_html.css("p.actions a[href='#{admin_access_requests_path}']").find { |link| link.text.squish == "すべての申請を見る" }
    expect(reset_link).to be_present
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_form
    parsed_html.at_css("form[action='#{admin_access_requests_path}']")
  end
end
