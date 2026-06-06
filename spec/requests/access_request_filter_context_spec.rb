require "rails_helper"

RSpec.describe "Access request filter context", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", file_size: 10) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows active status and search context when filters return no rows" do
    approver = create(:user, :internal)
    create(:access_request, requester: user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Policy review needed")

    sign_in_as(user)

    get access_requests_path, params: { q: "missing target", status: :approved }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中条件: 状態: 承認済み / 検索: missing target")
    expect(page_text).to include("状態: 承認済み / 検索: missing target に一致するアクセス申請はありません。")
    expect(page_text).to include("条件を外すと、送信済み申請全体を確認できます。")
    expect(page_text).to include("すべての申請を見る")
    expect(page_text).not_to include("送信済みのアクセス申請はありません。")
  end

  it "keeps pending cancel guidance focused on the row and current redirect behavior" do
    create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Need file approval")

    sign_in_as(user)

    get access_requests_path(status: :pending)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中条件: 状態: 申請中")
    expect(page_text).to include("この行の対象・要求権限・理由を確認してから取消してください。")
    expect(page_text).to include("取消後はフィルタなしのアクセス申請一覧で取消済みとして確認できます。")
    expect(response.body).to include("data-turbo-confirm")
    expect(response.body).to include("このアクセス申請を取り消します。対象・要求権限・理由を確認しましたか？")
  end

  def page_text
    Nokogiri::HTML.parse(response.body).text.squish
  end
end
