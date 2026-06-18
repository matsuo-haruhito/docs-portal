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

  def dashboard_section(title)
    parsed_html.css(".dashboard-grid .card").find do |section|
      section.at_css("h2")&.text&.squish == title
    end
  end

  def dashboard_section_links(title)
    dashboard_section(title).css("a")
  end

  def dashboard_section_text(title)
    dashboard_section(title).text.squish
  end

  def resource_items_for(title)
    dashboard_section(title).css("li.resource-list__item").map { _1.text.squish }
  end

  def create_viewable_document(title:, slug:, updated_at: Time.current)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external, updated_at:)
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
      "保留中のアクセス申請",
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
      "このダッシュボードは権限不足のエラーではありません。案件一覧・文書一覧から、現在閲覧できる範囲を確認できます。",
      "保留中のアクセス申請はありません。過去の申請は申請一覧で確認できます。",
      "参加中の案件は案件一覧で確認できます。",
      "お気に入りはまだ保存されていません。これは閲覧権限がない状態ではなく、個人用ショートカットが未利用の状態です。",
      "後で読む文書はまだ保存されていません。これは閲覧権限がない状態ではなく、個人用ショートカットが未利用の状態です。",
      "このアカウントでは最近見た文書がまだありません。文書一覧から読み始めると、直近の閲覧履歴がここに表示されます。",
      "閲覧可能な文書は文書一覧から確認できます。"
    )
    expect(dashboard_section_links("保留中のアクセス申請").map { |link| [link.text.squish, link["href"]] }).to include(["申請一覧で詳しく見る", access_requests_path])
    expect(dashboard_section_links("案件").map { |link| [link.text.squish, link["href"]] }).to include(["案件一覧へ", projects_path])

    ["お気に入り", "後で読む", "最近見た文書", "最近更新された文書"].each do |section_title|
      expect(dashboard_section_links(section_title).map { |link| [link.text.squish, link["href"]] }).to include(["文書一覧へ", documents_path])
    end
    expect(metric_cta_links.map { |link| link["href"] }).to include(
      projects_path,
      documents_path,
      document_bookmarks_path,
      access_requests_path
    )
    expect(metric_card_texts.any? { _1.include?("保留中の確認依頼") }).to be(false)
    expect(page_text).not_to include("社内向け導線", "確認依頼一覧", "管理ダッシュボード")
    expect(parsed_html.css(".dashboard-grid a").map { |link| link["href"] }).not_to include(document_approval_requests_path)
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

  it "shows recent pending access request summaries for the signed-in user only" do
    pending_project = create(:project, name: "Pending Project", code: "PND")
    older_pending_project = create(:project, name: "Older Pending Project", code: "OLD")
    other_user_project = create(:project, name: "Other User Project", code: "OTH")
    approved_project = create(:project, name: "Approved Project", code: "APR")
    other_user = create(:user, :external, company:)
    approver = create(:user, :internal)

    create(:access_request, requester: user, requestable: older_pending_project, requested_access_level: :view, created_at: 2.days.ago)
    create(:access_request, requester: user, requestable: pending_project, requested_access_level: :download, created_at: 1.hour.ago)
    create(:access_request, requester: other_user, requestable: other_user_project, requested_access_level: :manage)
    create(:access_request, requester: user, requestable: approved_project, status: :approved, approver:, approved_at: 1.day.ago)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(metric_card_for("保留中の申請")).to include("2", "申請一覧へ")
    expect(page_text).to include(
      "保留中のアクセス申請",
      "最近の申請を確認できます。",
      "Pending Project",
      "Older Pending Project",
      "ダウンロード",
      "閲覧",
      "申請中",
      "申請一覧で詳しく見る"
    )
    expect(page_text).not_to include("Other User Project", "Approved Project")
    expect(parsed_html.css(".dashboard-grid a").map { |link| link["href"] }).to include(access_requests_path)
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
      "markdown-preview-table-tools"
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

  it "bounds external dashboard short lists without showing unreadable personal documents" do
    fixed_time = Time.zone.local(2026, 1, 1, 12, 0, 0)
    10.times do |index|
      extra_project = create(:project, code: format("DASH%02d", index + 1), name: format("Visible Project %02d", index + 1))
      create(:project_membership, project: extra_project, user:)
    end
    create(:project, code: "DASH99", name: "Hidden Project")

    favorite_documents = 9.times.map do |index|
      create_viewable_document(
        title: format("Favorite Document %02d", index + 1),
        slug: format("favorite-document-%02d", index + 1),
        updated_at: fixed_time - (100 + index).minutes
      )
    end
    favorite_documents.each_with_index do |document, index|
      create(:document_bookmark, user:, document:, bookmark_type: :favorite, created_at: fixed_time - index.minutes)
    end

    read_later_documents = 9.times.map do |index|
      create_viewable_document(
        title: format("Read Later Document %02d", index + 1),
        slug: format("read-later-document-%02d", index + 1),
        updated_at: fixed_time - (200 + index).minutes
      )
    end
    read_later_documents.each_with_index do |document, index|
      create(:document_bookmark, user:, document:, bookmark_type: :read_later, created_at: fixed_time - index.minutes)
    end

    recent_documents = 11.times.map do |index|
      create_viewable_document(
        title: format("Recent Document %02d", index + 1),
        slug: format("recent-document-%02d", index + 1),
        updated_at: fixed_time - (300 + index).minutes
      )
    end
    recent_documents.each_with_index do |document, index|
      create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: fixed_time - index.minutes)
    end

    hidden_document = create(:document, project:, title: "Hidden Favorite Document", slug: "hidden-favorite", visibility_policy: :internal_only)
    create(:document_bookmark, user:, document: hidden_document, bookmark_type: :favorite, created_at: fixed_time + 1.minute)
    create(:access_log, user:, company:, project:, document: hidden_document, action_type: :view, target_type: "document", accessed_at: fixed_time + 1.minute)

    4.times do |index|
      request_project = create(:project, code: format("REQ%02d", index + 1), name: format("Pending Request Project %02d", index + 1))
      create(:access_request, requester: user, requestable: request_project, requested_access_level: :view, created_at: fixed_time - index.minutes)
    end
    create(:access_request, requester: create(:user, :external, company:), requestable: project, requested_access_level: :view, reason: "Other user request")

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(resource_items_for("案件").size).to eq(10)
      expect(resource_items_for("お気に入り").size).to eq(8)
      expect(resource_items_for("後で読む").size).to eq(8)
      expect(resource_items_for("最近見た文書").size).to eq(10)
      expect(resource_items_for("保留中のアクセス申請").size).to eq(3)

      expect(page_text).not_to include("Hidden Project")
      expect(dashboard_section_text("お気に入り")).to include("Favorite Document 01")
      expect(dashboard_section_text("お気に入り")).not_to include("Favorite Document 09")
      expect(page_text).not_to include("Hidden Favorite Document")
      expect(dashboard_section_text("後で読む")).to include("Read Later Document 01")
      expect(dashboard_section_text("後で読む")).not_to include("Read Later Document 09")
      expect(dashboard_section_text("最近見た文書")).to include("Recent Document 01")
      expect(dashboard_section_text("最近見た文書")).not_to include("Recent Document 11")
      expect(dashboard_section_text("保留中のアクセス申請")).to include("Pending Request Project 01")
      expect(dashboard_section_text("保留中のアクセス申請")).not_to include("Pending Request Project 04")
      expect(page_text).not_to include("Other user request")
      expect(page_text).not_to include("保留中の確認依頼")
      expect(page_text).not_to include("社内向け導線")
    end
  end

  it "bounds recently updated documents to accessible documents" do
    fixed_time = Time.zone.local(2026, 1, 2, 12, 0, 0)

    11.times do |index|
      create_viewable_document(
        title: format("Updated Document %02d", index + 1),
        slug: format("updated-document-%02d", index + 1),
        updated_at: fixed_time - index.minutes
      )
    end
    create(:document, project:, title: "Hidden Updated Document", slug: "hidden-updated", visibility_policy: :internal_only, updated_at: fixed_time + 1.minute)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(resource_items_for("最近更新された文書").size).to eq(10)
      expect(dashboard_section_text("最近更新された文書")).to include("Updated Document 01")
      expect(dashboard_section_text("最近更新された文書")).not_to include("Updated Document 11")
      expect(page_text).not_to include("Hidden Updated Document")
    end
  end

  it "keeps internal empty guidance from pointing only to admin navigation" do
    internal_user = create(:user, :internal)

    sign_in_as(internal_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(
      "保留タスクがない場合も、案件や文書の一覧から現在の担当範囲を確認できます。",
      "管理画面への移動は、管理権限がある場合だけ表示されます。"
    )
    expect(heading_texts).to include("社内向け導線")
    expect(parsed_html.css(".dashboard-grid a").map { |link| link["href"] }).to include(
      document_approval_requests_path,
      document_delivery_logs_path,
      admin_root_path
    )
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
