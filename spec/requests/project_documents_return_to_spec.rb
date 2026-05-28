require "rails_helper"

RSpec.describe "Project documents return_to", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DOCS1", name: "Portal Project") }
  let(:document) { create(:document, project:, title: "Portal Guide", slug: "portal-guide", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_hrefs
    parsed_html.css("a[href]").map { |node| node["href"] }
  end

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "preserves the current list context in the detail back link" do
    sign_in_as(external_user)
    return_to = project_documents_path(project, q: document.title, upload_source_path: "folder/subfolder")

    get project_documents_path(project), params: { q: document.title, upload_source_path: "folder/subfolder" }

    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(project_document_path(project, document.slug, return_to: return_to))

    get project_document_path(project, document.slug), params: { return_to: return_to }

    expect(response).to have_http_status(:ok)
    expect(href_for("文書一覧へ戻る")).to eq(return_to)
  end

  it "falls back to the default list path for non-root-relative return_to values" do
    sign_in_as(external_user)

    [
      "https://example.com/outside",
      "//example.com/outside",
      "javascript:alert(1)",
      "data:text/html,test",
      "documents/portal-guide"
    ].each do |unsafe_return_to|
      get project_document_path(project, document.slug), params: { return_to: unsafe_return_to }

      expect(response).to have_http_status(:ok)
      expect(href_for("文書一覧へ戻る")).to eq(project_documents_path(project))
    end
  end
end
