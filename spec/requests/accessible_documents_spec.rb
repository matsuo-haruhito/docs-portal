require "rails_helper"

RSpec.describe "AccessibleDocuments", type: :request do
  let(:company) { create(:company) }
  let(:project_a) { create(:project, name: "Alpha Project", code: "ALPHA") }
  let(:project_b) { create(:project, name: "Beta Project", code: "BETA") }
  let(:user) { create(:user, :external, company:) }

  def create_viewable_document(project:, title:, slug:, **attributes)
    document = create(:document, { project:, title:, slug:, visibility_policy: :restricted_external }.merge(attributes))
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  def add_project_access(project)
    create(:project_membership, project:, user:)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_response
    JSON.parse(response.body)
  end

  def project_column_texts
    parsed_html.css("table tbody tr td:first-child").map do |cell|
      cell.children.filter_map do |node|
        text = node.text.to_s.strip
        text if text.present?
      end.join(" ")
    end
  end

  def filter_form_action_links
    parsed_html.css("form.document-filter-form .form-actions a").map { _1.text.squish }
  end

  def document_title_texts
    parsed_html.css("table tbody tr td[data-rails-table-preferences-column-key='document']").map { _1.text.squish }
  end

  def pagination_href(text)
    parsed_html.css("nav.pagination a").find { |link| link.text.squish == text }&.[]("href")
  end

  before do
    add_project_access(project_a)
    add_project_access(project_b)
  end

  it "shows readable documents across accessible projects" do
    alpha = create_viewable_document(project: project_a, title: "Alpha Manual", slug: "alpha-manual")
    beta = create_viewable_document(project: project_b, title: "Beta Guide", slug: "beta-guide")
    hidden = create(:document, project: project_b, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)

    sign_in_as(user)
    get documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("閲覧可能文書")
    expect(response.body).to include(alpha.title, beta.title)
    expect(project_column_texts).to include("Alpha Project ALPHA", "Beta Project BETA")
    expect(page_text).not_to include("現在の条件:")
    expect(filter_form_action_links).not_to include("条件をクリア")
    expect(response.body).not_to include(hidden.title)
  end

  it "supports keyword filtering and pagination" do
    20.times do |index|
      create_viewable_document(project: project_a, title: "Reference #{index}", slug: "reference-#{index}")
    end
    target = create_viewable_document(project: project_b, title: "Approval Handbook", slug: "approval-handbook")
    other = create_viewable_document(project: project_b, title: "Billing Handbook", slug: "billing-handbook")

    sign_in_as(user)
    get documents_path, params: { q: "Approval" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(target.title)
    expect(response.body).not_to include(other.title)

    get documents_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/ページ\s*2\s*\/\s*2/)
  end

  it "returns project filter options only from visible documents" do
    visible_project = create(:project, code: "DOC001", name: "Visible Documents")
    hidden_project = create(:project, code: "DOC999", name: "Hidden Documents")
    add_project_access(visible_project)
    add_project_access(hidden_project)
    create_viewable_document(project: visible_project, title: "Visible Search Manual", slug: "visible-search-manual")
    create(:document, project: hidden_project, title: "Hidden Search Manual", slug: "hidden-search-manual", visibility_policy: :internal_only)

    sign_in_as(user)
    get project_search_documents_path(format: :json), params: { q: "doc" }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options")).to contain_exactly(
      include("value" => visible_project.id, "text" => "DOC001 / Visible Documents")
    )
  end

  it "bounds project search results and restores selected projects only when visible" do
    22.times do |index|
      project = create(:project, code: format("LIST%02d", index), name: "Listed Project #{index}")
      add_project_access(project)
      create_viewable_document(project:, title: "Listed Manual #{index}", slug: "listed-manual-#{index}")
    end
    selected_project = create(:project, code: "ZZZ99", name: "Selected Project")
    hidden_project = create(:project, code: "HIDE99", name: "Hidden Project")
    add_project_access(selected_project)
    add_project_access(hidden_project)
    create_viewable_document(project: selected_project, title: "Selected Manual", slug: "selected-manual")
    create(:document, project: hidden_project, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)

    sign_in_as(user)
    get project_search_documents_path(format: :json), params: { q: "Listed Project" }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options").size).to eq(AccessibleDocumentsController::PROJECT_SEARCH_LIMIT)

    get selected_project_documents_path(format: :json), params: { id: selected_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to include(
      "value" => selected_project.id,
      "text" => "ZZZ99 / Selected Project"
    )

    get selected_project_documents_path(format: :json), params: { id: hidden_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to be_nil

    get selected_project_documents_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to be_nil
  end

  it "filters documents by project and combines project with existing filters" do
    target = create_viewable_document(
      project: project_a,
      title: "Alpha Contract PDF",
      slug: "alpha-contract-pdf",
      category: :contract,
      document_kind: :pdf,
      visibility_policy: :restricted_external
    )
    same_project_wrong_category = create_viewable_document(project: project_a, title: "Alpha Manual", slug: "alpha-manual", category: :manual)
    other_project = create_viewable_document(project: project_b, title: "Beta Contract PDF", slug: "beta-contract-pdf", category: :contract, document_kind: :pdf)

    sign_in_as(user)
    get documents_path, params: { project_id: project_a.id, q: "Alpha", category: "contract", document_kind: "pdf" }

    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to eq([target.title])
    expect(page_text).to include("案件: ALPHA / Alpha Project")
    expect(page_text).to include("キーワード: Alpha")
    expect(page_text).to include("カテゴリ: 契約")
    expect(page_text).to include("ファイル種: PDF")
    expect(page_text).not_to include(same_project_wrong_category.title)
    expect(page_text).not_to include(other_project.title)
  end

  it "keeps project filter params on pagination links" do
    21.times do |index|
      create_viewable_document(
        project: project_a,
        title: format("Alpha Paged Manual %02d", index + 1),
        slug: format("alpha-paged-manual-%02d", index + 1)
      )
    end
    create_viewable_document(project: project_b, title: "Beta Paged Manual", slug: "beta-paged-manual")

    sign_in_as(user)
    get documents_path, params: { project_id: project_a.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件: ALPHA / Alpha Project")
    next_page_href = pagination_href("次へ")
    expect(next_page_href).to include("project_id=#{project_a.id}")
    expect(next_page_href).to include("page=2")
  end

  it "ignores inaccessible project filters without widening document visibility" do
    hidden_project = create(:project, name: "Hidden Project", code: "HIDDEN")
    hidden_document = create(:document, project: hidden_project, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)
    visible_document = create_viewable_document(project: project_a, title: "Visible Manual", slug: "visible-manual")

    sign_in_as(user)
    get documents_path, params: { project_id: hidden_project.id }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(visible_document.title)
    expect(response.body).not_to include(hidden_document.title)
    expect(page_text).not_to include("案件: HIDDEN / Hidden Project")
  end

  it "shows the form clear action only when filters are active" do
    document = create_viewable_document(project: project_a, title: "Tagged Manual", slug: "tagged-manual", category: :manual)
    tag = DocumentTag.create!(name: "設計資料")
    DocumentTagging.create!(document:, document_tag: tag)

    sign_in_as(user)
    get documents_path

    expect(response).to have_http_status(:ok)
    expect(filter_form_action_links).not_to include("条件をクリア")

    [
      { q: "Tagged" },
      { project_id: project_a.id },
      { tag: tag.normalized_name },
      { category: "manual" },
      { document_kind: "pdf" },
      { visibility_policy: "restricted_external" },
      { has_files: "1" }
    ].each do |params|
      get documents_path, params: params

      expect(response).to have_http_status(:ok)
      expect(filter_form_action_links).to include("条件をクリア")
    end
  end

  it "shows active filter summary near results" do
    target = create_viewable_document(
      project: project_a,
      title: "Quarterly Contract PDF",
      slug: "quarterly-contract-pdf",
      category: :contract,
      document_kind: :pdf,
      visibility_policy: :restricted_external
    )
    other = create_viewable_document(project: project_b, title: "Quarterly Manual", slug: "quarterly-manual", category: :manual)
    tag = DocumentTag.create!(name: "契約レビュー")
    DocumentTagging.create!(document: target, document_tag: tag)

    sign_in_as(user)
    get documents_path, params: {
      q: "Quarterly",
      project_id: project_a.id,
      tag: tag.normalized_name,
      category: "contract",
      document_kind: "pdf",
      visibility_policy: "restricted_external",
      has_pdf: "1"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(target.title)
    expect(response.body).not_to include(other.title)
    expect(page_text).to include("現在の条件:")
    expect(page_text).to include("キーワード: Quarterly")
    expect(page_text).to include("案件: ALPHA / Alpha Project")
    expect(page_text).to include("タグ: 契約レビュー")
    expect(page_text).to include("カテゴリ: 契約")
    expect(page_text).to include("ファイル種: PDF")
    expect(page_text).to include("公開範囲: 限定公開")
    expect(page_text).to include("PDFあり")
    expect(filter_form_action_links).to include("条件をクリア")
    expect(parsed_html.css("a").map { _1.text.squish }).to include("条件をクリア")
  end

  it "shows active filters in the empty state" do
    create_viewable_document(project: project_a, title: "Published Manual", slug: "published-manual", category: :manual)

    sign_in_as(user)
    get documents_path, params: { project_id: project_a.id, category: "contract", has_diagram: "1" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("現在の絞り込み条件に一致する閲覧可能な文書がありませんでした")
    expect(page_text).to include("案件: ALPHA / Alpha Project")
    expect(page_text).to include("カテゴリ: 契約")
    expect(page_text).to include("図あり")
    expect(parsed_html.css(".empty-state a").map { _1.text.squish }).to include("条件をクリア")
  end

  it "keeps active filter params on pagination links" do
    tag = DocumentTag.create!(name: "検索タグ")
    21.times do |index|
      document = create_viewable_document(
        project: project_a,
        title: format("Spec Reference %02d", index + 1),
        slug: format("spec-reference-%02d", index + 1),
        category: :spec,
        document_kind: :markdown,
        visibility_policy: :restricted_external
      )
      DocumentTagging.create!(document:, document_tag: tag)
      version = create(:document_version, document:, site_build_path: "spec-reference-#{index + 1}")
      document.update!(latest_version: version)
      create(:document_file, document_version: version, file_name: "spec-reference-#{index + 1}.pdf")
    end

    sign_in_as(user)
    get documents_path, params: {
      q: "Spec",
      project_id: project_a.id,
      tag: tag.normalized_name,
      category: "spec",
      document_kind: "markdown",
      visibility_policy: "restricted_external",
      has_html: "1",
      has_files: "1",
      has_pdf: "1"
    }

    expect(response).to have_http_status(:ok)
    next_page_href = pagination_href("次へ")
    expect(next_page_href).to include("q=Spec")
    expect(next_page_href).to include("project_id=#{project_a.id}")
    expect(next_page_href).to include("tag=#{CGI.escape(tag.normalized_name)}")
    expect(next_page_href).to include("category=spec")
    expect(next_page_href).to include("document_kind=markdown")
    expect(next_page_href).to include("visibility_policy=restricted_external")
    expect(next_page_href).to include("has_html=1")
    expect(next_page_href).to include("has_files=1")
    expect(next_page_href).to include("has_pdf=1")
    expect(next_page_href).to include("page=2")
  end

  it "applies practical checkbox filters from request params" do
    html_document = create_viewable_document(project: project_a, title: "HTML Manual", slug: "html-manual")
    attached_document = create_viewable_document(project: project_a, title: "Attached Manual", slug: "attached-manual")
    pdf_kind_document = create_viewable_document(project: project_b, title: "PDF Kind Handbook", slug: "pdf-kind-handbook", document_kind: :pdf)
    diagram_document = create_viewable_document(project: project_b, title: "Diagram Source", slug: "diagram-source")
    plain_document = create_viewable_document(project: project_b, title: "Plain Handbook", slug: "plain-handbook")

    html_version = create(:document_version, document: html_document, site_build_path: "html-manual")
    html_document.update!(latest_version: html_version)
    attached_version = create(:document_version, document: attached_document)
    create(:document_file, document_version: attached_version, file_name: "attached-manual.txt")
    create(:document_version, document: pdf_kind_document)
    create(:document_version, document: diagram_document, source_extension: "puml")
    create(:document_version, document: plain_document)

    sign_in_as(user)

    get documents_path, params: { has_html: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to eq([html_document.title])
    expect(page_text).to include("HTML生成済み")

    get documents_path, params: { has_files: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to eq([attached_document.title])
    expect(page_text).to include("添付あり")

    get documents_path, params: { has_pdf: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to eq([pdf_kind_document.title])
    expect(page_text).to include("PDFあり")

    get documents_path, params: { has_diagram: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to eq([diagram_document.title])
    expect(page_text).to include("図あり")
  end

  it "does not duplicate documents when PDF and diagram filters join multiple files" do
    pdf_document = create_viewable_document(project: project_a, title: "PDF Attachment Manual", slug: "pdf-attachment-manual")
    pdf_version = create(:document_version, document: pdf_document)
    create(:document_file, document_version: pdf_version, file_name: "manual.pdf")
    create(:document_file, document_version: pdf_version, file_name: "appendix.pdf")

    diagram_document = create_viewable_document(project: project_b, title: "Diagram Attachment Manual", slug: "diagram-attachment-manual")
    diagram_version = create(:document_version, document: diagram_document, source_extension: "puml")
    create(:document_file, document_version: diagram_version, file_name: "flow.mmd")
    create(:document_file, document_version: diagram_version, file_name: "sequence.d2")

    sign_in_as(user)

    get documents_path, params: { has_pdf: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts.count(pdf_document.title)).to eq(1)

    get documents_path, params: { has_diagram: "1" }
    expect(response).to have_http_status(:ok)
    expect(document_title_texts.count(diagram_document.title)).to eq(1)
  end

  it "ignores unsupported enum filters instead of failing the request" do
    spec_document = create_viewable_document(project: project_a, title: "Spec Manual", slug: "spec-manual", category: :spec)
    manual_document = create_viewable_document(project: project_b, title: "Regular Manual", slug: "regular-manual", category: :manual)

    sign_in_as(user)
    get documents_path, params: {
      category: "unknown-category",
      document_kind: "unknown-kind",
      visibility_policy: "unknown-visibility"
    }

    expect(response).to have_http_status(:ok)
    expect(document_title_texts).to include(spec_document.title, manual_document.title)
    expect(page_text).not_to include("カテゴリ:")
    expect(page_text).not_to include("ファイル種:")
    expect(page_text).not_to include("公開範囲:")
  end

  it "rounds invalid page params to the current pagination bounds" do
    21.times do |index|
      create_viewable_document(
        project: project_a,
        title: format("Paged Manual %02d", index + 1),
        slug: format("paged-manual-%02d", index + 1)
      )
    end

    sign_in_as(user)

    get documents_path, params: { page: 0 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/ページ\s*1\s*\/\s*2/)

    get documents_path, params: { page: -3 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/ページ\s*1\s*\/\s*2/)

    get documents_path, params: { page: 999 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/ページ\s*2\s*\/\s*2/)
  end

  it "keeps internal-only documents available to internal users" do
    internal_user = create(:user, :internal)
    internal_project = create(:project, name: "Internal Project")
    internal_document = create(:document, project: internal_project, title: "Internal Handbook", slug: "internal-handbook", visibility_policy: :internal_only)
    create(:project_membership, project: internal_project, user: internal_user)

    sign_in_as(internal_user)
    get documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(internal_document.title)
  end
end
