require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
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
    expect(response.body).to include("ダッシュボード")
    expect(response.body).to include("閲覧可能案件")
    expect(response.body).to include("Visible Project")
    expect(response.body).to include("お気に入り")
    expect(response.body).to include("後で読む")
    expect(response.body).to include("最近見た文書")
    expect(response.body).to include("最近更新された文書")
    expect(response.body).to include("Visible Manual")
    expect(metric_cta_links.map(&:text)).to include(
      "案件一覧へ",
      "案件から文書を探す",
      "ショートカット一覧へ",
      "申請一覧へ"
    )
    expect(metric_cta_links.map { |link| link["href"] }).to include(
      projects_path,
      document_bookmarks_path,
      access_requests_path
    )
    expect(response.body).not_to include(document_approval_requests_path)
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
    expect(response.body).to include("Visible Manual")
    expect(response.body).not_to include("Hidden Manual")
  end

  it "keeps internal approval navigation separate from summary actions" do
    internal_user = create(:user, :internal)

    sign_in_as(internal_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(metric_cta_links.map(&:text)).to include(
      "案件一覧へ",
      "案件から文書を探す",
      "ショートカット一覧へ",
      "申請一覧へ"
    )
    expect(metric_cta_links.map { |link| link["href"] }).not_to include(document_approval_requests_path)
    expect(parsed_html.css(".page-hero .actions a").map { |link| link["href"] }).to include(document_approval_requests_path)
  end
end
