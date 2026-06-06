require "rails_helper"

RSpec.describe "Document approval request index contract", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "依頼 太郎") }
  let(:approver) { create(:user, :internal, name: "確認 花子") }
  let(:internal_user) { create(:user, :internal, name: "一覧 管理者") }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "公開前確認資料", slug: "approval-contract-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def create_request!(document: self.document, requester: self.requester, approver: self.approver, title:, body: "確認本文", status: :pending, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"))
    attributes = {
      document:,
      requester:,
      approver:,
      title:,
      body:,
      status:,
      created_at:,
      updated_at: created_at
    }

    if status == :approved
      attributes[:acted_by] = internal_user
      attributes[:approved_at] = created_at + 1.hour
      attributes[:cancelled_at] = nil
    elsif status == :cancelled
      attributes[:acted_by] = requester
      attributes[:cancelled_at] = created_at + 1.hour
      attributes[:approved_at] = nil
    end

    create(:document_approval_request, **attributes)
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "allows only internal users to open the global index and keeps table preference columns stable" do
    create_request!(title: "全体一覧の確認依頼")

    sign_in_as(external_user)
    get document_approval_requests_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(internal_user)
    get document_approval_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("対応待ち 1件 / OK済み 0件 / Cancel済み 0件")
    expect(response.body).to include("確認依頼一覧の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="created_at"')
    expect(response.body).to include('data-rails-table-preferences-column-key="document"')
    expect(response.body).to include('data-rails-table-preferences-column-key="title"')
    expect(response.body).to include('data-rails-table-preferences-column-key="requester"')
    expect(response.body).to include('data-rails-table-preferences-column-key="approver"')
    expect(response.body).to include('data-rails-table-preferences-column-key="status"')
  end

  it "treats unsupported status values as no-op instead of failing or forcing an empty result" do
    pending_request = create_request!(title: "未処理の確認")
    approved_request = create_request!(title: "OK済みの確認", status: :approved, created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { status: "archived" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(pending_request.title)
    expect(page_text).to include(approved_request.title)
    expect(page_text).to include("対応待ち 1件 / OK済み 1件 / Cancel済み 0件")
    expect(page_text).not_to include("検索を解除")
  end

  it "searches representative request, document, requester, and approver fields" do
    body_match = create_request!(title: "本文一致依頼", body: "契約条項の確認が必要です")
    document_match = create_request!(title: "slug一致依頼", document:, body: "通常本文", created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))
    requester_match = create_request!(title: "依頼者一致依頼", requester:, body: "通常本文", created_at: Time.zone.parse("2026-05-03 00:00:00 UTC"))
    approver_match = create_request!(title: "確認相手一致依頼", approver:, body: "通常本文", created_at: Time.zone.parse("2026-05-04 00:00:00 UTC"))
    other_document = create(:document, project:, title: "対象外資料", slug: "outside-doc", visibility_policy: :restricted_external)
    other_requester = create(:user, :external, company:, name: "対象外 依頼者")
    other_approver = create(:user, :internal, name: "対象外 確認者")
    create(:project_membership, project:, user: other_requester)
    create(:document_permission, document: other_document, company:, access_level: :view)
    non_matching_request = create_request!(
      document: other_document,
      requester: other_requester,
      approver: other_approver,
      title: "対象外依頼",
      body: "通常本文",
      created_at: Time.zone.parse("2026-05-05 00:00:00 UTC")
    )

    sign_in_as(internal_user)

    aggregate_failures "query fields" do
      get document_approval_requests_path, params: { q: "契約条項" }
      expect(response).to have_http_status(:ok)
      expect(page_text).to include(body_match.title)
      expect(page_text).not_to include(non_matching_request.title)

      get document_approval_requests_path, params: { q: "approval-contract-doc" }
      expect(response).to have_http_status(:ok)
      expect(page_text).to include(document_match.title)
      expect(page_text).not_to include(non_matching_request.title)

      get document_approval_requests_path, params: { q: "依頼 太郎" }
      expect(response).to have_http_status(:ok)
      expect(page_text).to include(requester_match.title)
      expect(page_text).not_to include(non_matching_request.title)

      get document_approval_requests_path, params: { q: "確認 花子" }
      expect(response).to have_http_status(:ok)
      expect(page_text).to include(approver_match.title)
      expect(page_text).not_to include(non_matching_request.title)
    end
  end

  it "keeps status and query filters in detail return_to links" do
    matching_request = create_request!(title: "契約レビュー依頼", body: "契約条項を確認してください")
    create_request!(
      title: "処理済み契約レビュー",
      body: "契約条項を確認済みです",
      status: :approved,
      created_at: Time.zone.parse("2026-05-02 00:00:00 UTC")
    )

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { status: :pending, q: "契約" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(matching_request.title)
    expect(page_text).not_to include("処理済み契約レビュー")
    expect(page_text).to include("検索条件: 契約 / 表示 1件")

    detail_link = parsed_html.css(%(a[href^="#{document_approval_request_path(matching_request)}"])).find { |link| link.text == matching_request.title }
    expect(detail_link).to be_present

    query = Rack::Utils.parse_nested_query(URI.parse(detail_link["href"]).query)
    return_to = URI.parse(query.fetch("return_to"))
    return_to_params = Rack::Utils.parse_nested_query(return_to.query)
    expect(return_to.path).to eq(document_approval_requests_path)
    expect(return_to_params).to include("status" => "pending", "q" => "契約")
  end

  it "falls back from unsafe return_to values on detail links and post-action redirects" do
    sign_in_as(internal_user)

    {
      "absolute URL" => "https://example.com/document_approval_requests",
      "protocol-relative URL" => "//example.com/document_approval_requests"
    }.each do |label, unsafe_return_to|
      approval_request = create_request!(title: "unsafe return_to #{label}")

      get document_approval_request_path(approval_request), params: { return_to: unsafe_return_to }

      expect(response).to have_http_status(:ok)
      back_link = parsed_html.css("a").find { |link| link.text.strip == "一覧へ戻る" }
      expect(back_link).to be_present
      expect(back_link["href"]).to eq(document_approval_requests_path)

      patch document_approval_request_path(approval_request), params: { return_to: unsafe_return_to }

      expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: document_approval_requests_path))
    end
  end
end
