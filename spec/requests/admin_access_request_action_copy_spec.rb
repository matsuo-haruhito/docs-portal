require "rails_helper"

RSpec.describe "Admin access request action copy", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "ACT", name: "Action Project") }
  let(:document) { create(:document, project:, title: "Action Manual", slug: "action-manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def row_for(reason)
    parsed_html.css("tbody tr").find { |row| row.text.include?(reason) }
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "keeps approval and rejection cues close to pending row actions without changing action params" do
    manage_request = create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :manage,
      reason: "Need project management")
    download_request = create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :download,
      reason: "Need manual download")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: {
      status: "pending",
      q: "Need",
      requested_access_level: "manage",
      requestable_type: "Project"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("却下: 理由を残して申請を閉じます。権限は変更しません。")
    expect(page_text).to include("定型候補は入力補助です。補足も却下理由の入力補助です。承認基準や権限付与仕様はここでは変更しません。")
    expect(page_text).not_to include("一括承認", "一括却下")

    manage_row = row_for("Need project management")
    expect(manage_row.text.squish).to include("管理権限申請")
    expect(manage_row.text.squish).to include("現行の承認処理では管理者 role を付与しません")
    expect(manage_row.text.squish).to include("管理権限申請は自動承認できません。権限設定を別途確認してください。")

    action_forms = manage_row.css("form[action='#{admin_access_request_path(manage_request)}']")
    expect(action_forms.size).to eq(1)
    reject_form = action_forms.first

    expect(reject_form.at_css("input[name='decision'][value='reject']")).to be_present
    expect(reject_form.at_css("input[name='decision'][value='approve']")).to be_nil
    expect(reject_form.at_css("input[name='status']")["value"]).to eq("pending")
    expect(reject_form.at_css("input[name='q']")["value"]).to eq("Need")
    expect(reject_form.at_css("input[name='requested_access_level']")["value"]).to eq("manage")
    expect(reject_form.at_css("input[name='requestable_type']")["value"]).to eq("Project")

    get admin_access_requests_path, params: { status: "pending", requested_access_level: "download" }

    expect(response).to have_http_status(:ok)
    download_row = row_for("Need manual download")
    expect(download_row.text.squish).to include("判断前に対象・要求権限・理由を確認してください。")
    expect(download_row.text.squish).to include("却下: 理由を残して申請を閉じます。権限は変更しません。")
    expect(download_row.text.squish).not_to include("管理権限申請は自動承認できません")
    download_forms = download_row.css("form[action='#{admin_access_request_path(download_request)}']")
    expect(download_forms.size).to eq(2)
    expect(download_forms.first.at_css("input[name='decision'][value='approve']")).to be_present
    expect(download_forms.last.at_css("input[name='decision'][value='reject']")).to be_present
  end
end
