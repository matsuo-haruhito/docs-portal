require "rails_helper"

RSpec.describe "Document catalogs", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "CATALOG", name: "Catalog Project") }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def catalog_table_text
    parsed_html.css("table").map(&:text).join("\n")
  end

  def main_text
    parsed_html.at("main")&.text.to_s
  end

  def catalog_summary_text
    parsed_html.css("section.document-catalog-summary").map { |section| section.text.squish }.join("\n")
  end

  def reusable_filter_link
    parsed_html.css("a").find { |link| link.text.squish == "現在の条件のURLを開く" }
  end

  def reusable_filter_query
    Rack::Utils.parse_nested_query(URI.parse(reusable_filter_link["href"]).query)
  end

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "lists viewable catalogs for the project" do
    visible = create(:document_catalog, project:, name: "Customer Pack", description: "契約前に共有する導入資料をまとめたカタログです", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog, project:, name: "Internal Pack", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書カタログ")
    expect(response.body).to include("Customer Pack")
    expect(response.body).to include("契約前に共有する導入資料をまとめたカタログです")
    expect(response.body).to include("顧客向け")
    expect(response.body).to include("限定公開")
    expect(response.body).to include("表示可能件数")
    expect(response.body).to include("現在の利用者に見える文書")
    expect(response.body).to include("現在の利用者に表示")
    expect(response.body).not_to include("Internal Pack")
    expect(catalog_table_text).not_to include("restricted_external")
    expect(response.body).to include(project_document_catalog_path(project, visible))
  end

  it "searches catalogs by name and description" do
    create(:document_catalog, project:, name: "Customer Onboarding", description: "Initial customer documents")
    create(:document_catalog, project:, name: "Operations Pack", description: "Runbook for incident response", audience_type: :operations)
    create(:document_catalog, project:, name: "Developer Guide", description: "SDK reference", audience_type: :developer)

    sign_in_as(external_user)

    get project_document_catalogs_path(project, q: "runbook")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Operations Pack")
    expect(response.body).not_to include("Customer Onboarding")
    expect(response.body).not_to include("Developer Guide")
    expect(main_text).to include("現在の絞り込み")
    expect(main_text).to include("名称・説明: runbook")
    expect(main_text).to include("表示可能件数は、現在の利用者が閲覧できる文書だけを数えます。")
  end

  it "does not match document or catalog item text with the index search" do
    document = create(:document, project:, title: "Needle Handbook", slug: "needle-handbook", visibility_policy: :restricted_external)
    catalog = create(:document_catalog, project:, name: "Customer Pack", description: "Portal package")
    create(:document_catalog_item, document_catalog: catalog, document:, note: "Needle note")

    sign_in_as(external_user)

    get project_document_catalogs_path(project, q: "needle")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する文書カタログはありません。検索語・対象・公開範囲を確認するか、絞り込みを解除してください。")
    expect(response.body).not_to include("Customer Pack")
    expect(response.body).not_to include("Needle Handbook")
    expect(response.body).not_to include("Needle note")
    expect(main_text).to include("名称・説明: needle")
  end

  it "combines audience and visibility filters" do
    create(:document_catalog, project:, name: "Customer Private", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog, project:, name: "Customer Login", audience_type: :customer, visibility_policy: :public_with_login)
    create(:document_catalog, project:, name: "Operations Login", audience_type: :operations, visibility_policy: :public_with_login)

    sign_in_as(external_user)

    get project_document_catalogs_path(
      project,
      q: "login",
      audience_type: "customer",
      visibility_policy: "public_with_login",
      saved_filter_id: "should-not-be-kept",
      preset_id: "shared-preset"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Customer Login")
    expect(response.body).not_to include("Customer Private")
    expect(response.body).not_to include("Operations Login")
    expect(main_text).to include("名称・説明: login")
    expect(main_text).to include("対象: 顧客向け")
    expect(main_text).to include("公開範囲: ログインユーザー公開")
    expect(main_text).to include("現在の条件だけを含むURLです。開いても閲覧権限は現在の利用者で再確認されます。")
    expect(main_text).not_to include("public_with_login")

    expect(reusable_filter_link["href"]).to start_with(project_document_catalogs_path(project))
    expect(reusable_filter_query).to eq(
      "q" => "login",
      "audience_type" => "customer",
      "visibility_policy" => "public_with_login"
    )
    expect(reusable_filter_link["href"]).not_to include("saved_filter_id")
    expect(reusable_filter_link["href"]).not_to include("preset_id")
  end

  it "does not expose catalogs outside the viewer boundary through filters" do
    create(:document_catalog, project:, name: "External Runbook", description: "Shared operations", audience_type: :operations, visibility_policy: :restricted_external)
    create(:document_catalog, project:, name: "Internal Runbook", description: "Secret operations", audience_type: :operations, visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_document_catalogs_path(project, q: "runbook", audience_type: "operations", visibility_policy: "internal_only")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する文書カタログはありません。検索語・対象・公開範囲を確認するか、絞り込みを解除してください。")
    expect(main_text).to include("名称・説明: runbook")
    expect(main_text).to include("対象: 運用向け")
    expect(main_text).to include("公開範囲: 社内のみ")
    expect(main_text).not_to include("internal_only")
    expect(response.body).not_to include("Internal Runbook")
    expect(response.body).not_to include("External Runbook")
    expect(reusable_filter_query).to eq(
      "q" => "runbook",
      "audience_type" => "operations",
      "visibility_policy" => "internal_only"
    )
  end

  it "ignores unsupported filters without raising an error" do
    create(:document_catalog, project:, name: "Customer Pack", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog, project:, name: "Developer Pack", audience_type: :developer, visibility_policy: :public_with_login)

    sign_in_as(external_user)

    get project_document_catalogs_path(project, audience_type: "unknown", visibility_policy: "archived")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Customer Pack")
    expect(response.body).to include("Developer Pack")
    expect(main_text).not_to include("現在の絞り込み")
    expect(main_text).not_to include("unknown")
    expect(main_text).not_to include("archived")
    expect(reusable_filter_link).to be_nil
  end

  it "shows an unregistered empty state separately from a filtered empty state" do
    sign_in_as(external_user)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("利用可能な文書カタログはありません。")
    expect(response.body).not_to include("条件に一致する文書カタログはありません。")
    expect(main_text).not_to include("現在の絞り込み")
  end

  it "explains catalog details with no registered items" do
    catalog = create(:document_catalog, project:, name: "Empty Customer Pack", audience_type: :customer, visibility_policy: :restricted_external)

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Empty Customer Pack")
    expect(catalog_summary_text).to include("カタログ概要")
    expect(catalog_summary_text).to include("案件 Catalog Project")
    expect(catalog_summary_text).to include("対象 顧客向け")
    expect(catalog_summary_text).to include("公開範囲 限定公開")
    expect(catalog_summary_text).to include("表示可能 0件")
    expect(catalog_summary_text).to include("登録 0件")
    expect(main_text).to include("このカタログにはまだ文書が登録されていません。")
    expect(main_text).not_to include("登録済みの文書はあります")
    expect(response.body).to include(project_document_catalogs_path(project))
  end

  it "explains catalog details with registered items that are not visible to the current user" do
    hidden_document = create(:document, project:, title: "Internal Manual", slug: "internal-manual", visibility_policy: :internal_only)
    create(:document_version, document: hidden_document, version_label: "v1.0.0", status: :published)
    catalog = create(:document_catalog, project:, name: "Hidden Customer Pack", audience_type: :delivery, visibility_policy: :restricted_external)
    create(:document_catalog_item, document_catalog: catalog, document: hidden_document, sort_order: 1, note: "internal note")

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hidden Customer Pack")
    expect(catalog_summary_text).to include("対象 納品向け")
    expect(catalog_summary_text).to include("公開範囲 限定公開")
    expect(catalog_summary_text).to include("表示可能 0件")
    expect(catalog_summary_text).to include("登録 1件")
    expect(main_text).to include("登録済みの文書はありますが、現在の利用者に表示できる文書はありません。")
    expect(main_text).not_to include("このカタログにはまだ文書が登録されていません。")
    expect(response.body).not_to include("Internal Manual")
    expect(response.body).not_to include("internal note")
    expect(main_text).not_to include("internal_only")
    expect(response.body).to include(project_document_catalogs_path(project))
  end

  it "shows only visible items in a catalog" do
    visible_document = create(:document, project:, title: "Visible Manual", slug: "visible-manual", visibility_policy: :restricted_external)
    hidden_document = create(:document, project:, title: "Internal Manual", slug: "internal-manual", visibility_policy: :internal_only)
    visible_version = create(:document_version, document: visible_document, version_label: "v1.0.0", status: :published)
    visible_document.update!(latest_version: visible_version)
    create(:document_permission, document: visible_document, company:, access_level: :view)

    catalog = create(:document_catalog, project:, name: "Customer Pack", audience_type: :delivery, visibility_policy: :restricted_external)
    create(:document_catalog_item, document_catalog: catalog, document: hidden_document, sort_order: 1, note: "internal")
    create(:document_catalog_item, document_catalog: catalog, document: visible_document, sort_order: 2, note: "read first")

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Customer Pack")
    expect(catalog_summary_text).to include("対象 納品向け")
    expect(catalog_summary_text).to include("公開範囲 限定公開")
    expect(catalog_summary_text).to include("表示可能 1件")
    expect(catalog_summary_text).to include("登録 2件")
    expect(response.body).to include("Visible Manual")
    expect(response.body).to include("read first")
    expect(response.body).not_to include("Internal Manual")
    expect(response.body).not_to include("internal")
    expect(main_text).not_to include("restricted_external")
  end

  it "forbids external users from internal-only catalogs" do
    catalog = create(:document_catalog, project:, visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids external users without project membership from the catalog index" do
    other_external_user = create(:user, :external, company:)
    create(:document_catalog, project:, name: "Customer Pack", visibility_policy: :restricted_external)

    sign_in_as(other_external_user)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include("Customer Pack")
  end

  it "forbids external users without project membership from catalog details" do
    other_external_user = create(:user, :external, company:)
    catalog = create(:document_catalog, project:, name: "Customer Pack", visibility_policy: :restricted_external)

    sign_in_as(other_external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include("Customer Pack")
  end

  it "allows internal users to view internal-only catalogs" do
    document = create(:document, project:, title: "Internal Manual", slug: "internal-manual", visibility_policy: :internal_only)
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    catalog = create(:document_catalog, project:, name: "Internal Pack", visibility_policy: :internal_only)
    create(:document_catalog_item, document_catalog: catalog, document:, sort_order: 1)

    sign_in_as(internal_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Internal Pack")
    expect(response.body).to include("Internal Manual")
  end
end