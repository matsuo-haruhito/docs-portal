require "rails_helper"

RSpec.describe "Dashboard short-list links", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def dashboard_section(title)
    parsed_html.css(".dashboard-grid .card").find do |section|
      section.at_css("h2")&.text&.squish == title
    end
  end

  def dashboard_section_links(title)
    dashboard_section(title).css("a").map { |link| [link.text.squish, link["href"]] }
  end

  def create_viewable_document(title:, slug:, updated_at: Time.current)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external, updated_at:)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "links populated dashboard document lists to their existing full-list destinations" do
    document = create_viewable_document(title: "Visible Manual", slug: "visible-manual")
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: Time.current)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(dashboard_section_links("お気に入り")).to include(["ショートカット一覧でさらに見る", document_bookmarks_path])
    expect(dashboard_section_links("後で読む")).to include(["ショートカット一覧でさらに見る", document_bookmarks_path])
    expect(dashboard_section_links("最近見た文書")).to include(["文書一覧でさらに探す", documents_path])
    expect(dashboard_section_links("最近更新された文書")).to include(["文書一覧でさらに探す", documents_path])
  end
end
