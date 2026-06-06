require "rails_helper"

RSpec.describe "Admin access request action grouping", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "explains approve and reject actions without changing the pending forms" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need manual download")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("判断前に対象・要求権限・理由を確認してください。")
    expect(page_text).to include("承認: 要求権限を付与します。")
    expect(page_text).to include("却下: 理由を残して申請を閉じます。")
    expect(page_text).to include("却下理由の定型候補")
    expect(page_text).to include("補足（任意）")

    action_forms = parsed_html.css("form[action='#{admin_access_request_path(access_request)}']")
    reject_form = action_forms.last

    expect(action_forms.size).to eq(2)
    expect(reject_form.at_css("input[name='decision'][value='reject']")).to be_present
    expect(reject_form.at_css("select[name='rejection_reason_preset']")).to be_present
    expect(reject_form.at_css("textarea[name='rejection_reason_note']")).to be_present
  end

  it "keeps manage request warnings visible next to the action guidance" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :manage, reason: "Need project management")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    row = parsed_html.css("tbody tr").find { |node| node.text.include?("Need project management") }

    expect(response).to have_http_status(:ok)
    expect(row.text.squish).to include("管理権限申請")
    expect(row.text.squish).to include("現行の承認処理では管理者 role を付与しません")
    expect(row.text.squish).to include("判断前に対象・要求権限・理由を確認してください。")
    expect(row.css("form[action='#{admin_access_request_path(access_request)}']").size).to eq(2)
  end
end
