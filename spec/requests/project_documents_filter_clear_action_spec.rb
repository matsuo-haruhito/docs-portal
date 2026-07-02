require "rails_helper"

RSpec.describe "Project document filter clear action", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "CLEAR1", name: "Clear Link Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_form_action_links
    parsed_html.css("form.document-filter-form .form-actions a").map { _1.text.squish }
  end

  def empty_state_links
    parsed_html.css(".empty-state a").map { _1.text.squish }
  end

  before do
    document = create(
      :document,
      project:,
      title: "Alpha Manual",
      slug: "alpha-manual",
      category: :manual,
      document_kind: :markdown,
      visibility_policy: :internal_only
    )
    tag = DocumentTag.create!(name: "設計資料")
    DocumentTagging.create!(document:, document_tag: tag)

    version = create(:document_version, document:, site_build_path: "alpha-manual", source_extension: "puml")
    document.update!(latest_version: version)
    create(:document_file, document_version: version, file_name: "alpha-manual.pdf")
  end

  it "hides the form clear action until a filter is active" do
    sign_in_as(user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Alpha Manual")
    expect(filter_form_action_links).not_to include("条件をクリア")
  end

  it "shows the form clear action when any document filter is active" do
    sign_in_as(user)

    [
      { q: "Alpha" },
      { tag: "設計資料" },
      { category: "manual" },
      { document_kind: "markdown" },
      { visibility_policy: "internal_only" },
      { has_html: "1" },
      { has_files: "1" },
      { has_pdf: "1" },
      { has_diagram: "1" }
    ].each do |params|
      get project_documents_path(project), params: params

      expect(response).to have_http_status(:ok)
      expect(filter_form_action_links).to include("条件をクリア")
    end
  end

  it "keeps the empty-state clear action when filters return no documents" do
    sign_in_as(user)

    get project_documents_path(project), params: { q: "missing keyword" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する文書はありません")
    expect(filter_form_action_links).to include("条件をクリア")
    expect(empty_state_links).to include("条件をクリア")
  end
end
