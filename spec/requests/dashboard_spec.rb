require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def heading_texts
    parsed_html.css("h1, h2, h3").map { _1.text.squish }.reject(&:empty?)
  end

  def metric_card_texts
    parsed_html.css(".metric-card").map { _1.text.squish }
  end

  def metric_card_for(label)
    metric_card_texts.find { _1.include?(label) }
  end

  def metric_cta_links
    parsed_html.css(".metric-card .metric-card__cta")
  end

  def create_viewable_document(title:, slug:)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "shows user dashboard sections" do
    document = create_viewable_document(title: "Visible Manual", slug: "visible-manual")
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: Time.current)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("ダッシュボード", "最近見た文書", "最近更新された文書")
    expect(metric_card_texts.any? { _1.include?("閲覧可能案件") }).to be(true)
    expect(page_text).to include("Visible Project", "Visible Manual", "お気に入り", "後で読む")
    expect(metric_cta_links.map(&:text)).to include(
      "案件一覧へ",
      "文書一覧へ",
      "ショートカット一覧へ",
      "申請一覧へ"
    )
    expect(metric_cta_links.map { |link| link["href"] }).to include(
      projects_path,
      documents_path,
      document_bookmarks_path,
      access_requests_path
    )
    expect(metric_card_texts.any? { _1.include?("保留中の確認依頼") }).to be(false)
    expect(metric_cta_links.map { |link| link["href"] }).not_to include(document_approval_requests_path)
  end

  it "keeps the external user dashboard usable when all personal sections are empty" do
    empty_user = create(:user, :external, company:)

    sign_in_as(empty_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include(
      "ダッシュボード",
      "案件",
      "お気に入り",
      "後で読む",
      "最近見た文書",
      "最近更新された文書"
    )
    expect(metric_card_for("閲覧可能案件")).to include("0", "案件一覧へ")
    expect(metric_card_for("閲覧可能文書")).to include("0", "文書一覧へ")
    expect(metric_card_for("保存ショートカット")).to include("0", "ショートカット一覧へ")
    expect(metric_card_for("保留中の申請")).to include("0", "申請一覧へ")
    expect(page_text).to include(
      "閲覧可能な案件はありません。",
      "お気に入りはありません。",
      "後で読む文書はありません。",
      "最近見た文書はありません。",
      "最近更新された文書はありません。"
    )
    expect(metric_cta_links.map { |link| link["href"] }).to include(
      projects_path,
      documents_path,
      document_bookmarks_path,
      access_requests_path
    )
    expect(metric_card_texts.any? { _1.include?("保留中の確認依頼") }).to be(false)
    expect(page_text).not_to include("社内向け導線", "確認依頼一覧")
    expect(metric_cta_links.map { |link| link["href"] }).not_to include(document_approval_requests_path)
  end

  it "counts only the signed-in external user's pending access requests" do
    other_user = create(:user, :external, company:)
    create(:access_request, requester: user, requestable: project)
    create(:access_request, requester: other_user, requestable: project)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(metric_card_for("保留中の申請")).to include("1", "申請一覧へ")
    expect(metric_cta_links.map { |link| link["href"] }).to include(access_requests_path)
    expect(metric_card_texts.any? { _1.include?("保留中の確認依頼") }).to be(false)
    expect(metric_cta_links.map { |link| link["href"] }).not_to include(document_approval_requests_path)
  end

  it "declares root stimulus controllers in the full-page layout markup" do
    create_viewable_document(title: "Visible Manual", slug: "visible-manual")

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)

    body = parsed_html.at_css("body")

    expect(body).to be_present
    expect(body["data-controller"].to_s.split).to include(
      "nav-dropdowns",
      "document-tree-navigation",
      "manual-document-upload",
      "preview-table-resizer",
      "preview-tools"
    )
  end

  it "does not show documents that are not readable by the user" do
    visible = create_viewable_document(title: "Visible Manual", slug: "visible-manual")
    hidden = create(:document, project:, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)
    create(:document_bookmark, user:, document: visible, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: hidden, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: hidden, action_type: :view, target_type: "document", accessed_at: Time.current)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Visible Manual")
    expect(page_text).not_to include("Hidden Manual")
  end

  it "shows pending approval summary for internal users while keeping the hero action separate" do
    internal_user = create(:user, :internal)
    approval_project = create(:project, code: "APR", name: "Approval Project")
    approval_document = create(:document, project: approval_project, title: "確認資料", slug: "approval-doc")
    create(:document_approval_request, document: approval_document, requester: internal_user, approver: internal_user, title: "確認お願いします")

    sign_in_as(internal_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)

    pending_approval_card = metric_card_texts.find { _1.include?("保留中の確認依頼") }

    expect(pending_approval_card).to be_present
    expect(pending_approval_card).to include("1")
    expect(metric_cta_links.map(&:text)).to include(
      "案件一覧へ",
      "文書一覧へ",
      "ショートカット一覧へ",
      "申請一覧へ",
      "未処理の確認依頼を見る"
    )
    expect(metric_cta_links.map { |link| link["href"] }).to include(document_approval_requests_path)
    expect(parsed_html.css(".page-hero .actions a").map { |link| link["href"] }).not_to include(document_approval_requests_path)
    expect(parsed_html.css(".dashboard-grid a").map { |link| link["href"] }).to include(document_approval_requests_path)
  end
end
