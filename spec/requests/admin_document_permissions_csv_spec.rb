require "rails_helper"
require "csv"

RSpec.describe "Admin document permissions CSV", type: :request do
  let(:admin_user) { create(:user, :internal) }

  CSV_HEADERS = [
    "案件コード",
    "案件名",
    "文書名",
    "slug",
    "公開範囲",
    "付与先種別",
    "会社名",
    "会社domain",
    "ユーザー名",
    "ユーザーemail",
    "権限",
    "作成日時",
    "更新日時"
  ].freeze

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  def csv_rows
    parsed_csv.map(&:to_h)
  end

  def csv_row_for(document_title)
    csv_rows.find { _1["文書名"] == document_title }
  end

  it "exports fixed audit columns for individual permission rows" do
    project = create(:project, code: "AUDIT", name: "Audit Project")
    document = create(:document, project:, title: "Audit Guide", slug: "audit-guide", visibility_policy: :restricted_external)
    company = create(:company, name: "Audit Company", domain: "audit.example")
    user = create(:user, :external, name: "Audit User", email_address: "audit-user@example.com")
    company_permission = create(:document_permission, document:, company:, access_level: :view)
    user_permission = create(:document_permission, document:, user:, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path(format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("document-permissions-")
    expect(parsed_csv.headers).to eq(CSV_HEADERS)
    expect(csv_rows.size).to eq(2)

    company_row = csv_row_for("Audit Guide")
    expect(company_row).to include(
      "案件コード" => "AUDIT",
      "案件名" => "Audit Project",
      "文書名" => "Audit Guide",
      "slug" => "audit-guide",
      "公開範囲" => "限定公開",
      "付与先種別" => "会社単位",
      "会社名" => "Audit Company",
      "会社domain" => "audit.example",
      "ユーザー名" => nil,
      "ユーザーemail" => nil,
      "権限" => "閲覧",
      "作成日時" => company_permission.created_at.iso8601,
      "更新日時" => company_permission.updated_at.iso8601
    )

    user_row = csv_rows.find { _1["付与先種別"] == "ユーザー単位" }
    expect(user_row).to include(
      "会社名" => nil,
      "会社domain" => nil,
      "ユーザー名" => "Audit User",
      "ユーザーemail" => "audit-user@example.com",
      "権限" => "ダウンロード",
      "作成日時" => user_permission.created_at.iso8601,
      "更新日時" => user_permission.updated_at.iso8601
    )
  end

  it "keeps project and document query filters aligned with the HTML index" do
    target_project = create(:project, code: "TARGET", name: "Target Project")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    target_document = create(:document, project: target_project, title: "Filtered Runbook", slug: "filtered-runbook")
    other_project_document = create(:document, project: other_project, title: "Filtered Runbook", slug: "other-filtered-runbook")
    other_title_document = create(:document, project: target_project, title: "Unmatched Manual", slug: "unmatched-manual")
    create(:document_permission, document: target_document, company: create(:company, name: "Target Company"))
    create(:document_permission, document: other_project_document, company: create(:company, name: "Other Company"))
    create(:document_permission, document: other_title_document, company: create(:company, name: "Unmatched Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(format: :csv), params: { project_id: target_project.id, q: "runbook" }

    expect(response).to have_http_status(:ok)
    expect(csv_rows.map { _1["文書名"] }).to eq(["Filtered Runbook"])
    expect(csv_rows.first["案件コード"]).to eq("TARGET")
    expect(csv_rows.first["会社名"]).to eq("Target Company")
  end

  it "keeps access level and target type filters aligned with the HTML index" do
    document = create(:document, title: "Scoped Permission Guide")
    create(:document_permission, document:, company: create(:company, name: "Company Scope"), access_level: :view)
    create(:document_permission, document:, user: create(:user, :external, name: "User Scope", email_address: "scope@example.com"), access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path(format: :csv), params: { access_level: "download", target_type: "user" }

    expect(response).to have_http_status(:ok)
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first).to include(
      "文書名" => "Scoped Permission Guide",
      "付与先種別" => "ユーザー単位",
      "ユーザー名" => "User Scope",
      "権限" => "ダウンロード"
    )
  end

  it "ignores invalid filters without changing the fixed CSV columns" do
    document = create(:document, title: "Invalid Filter Fallback")
    create(:document_permission, document:, company: create(:company, name: "Fallback Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(format: :csv), params: {
      project_id: "999999",
      access_level: "owner",
      target_type: "team",
      table_key: "admin_document_permissions",
      columns: "document"
    }

    expect(response).to have_http_status(:ok)
    expect(parsed_csv.headers).to eq(CSV_HEADERS)
    expect(csv_rows.map { _1["文書名"] }).to eq(["Invalid Filter Fallback"])
    expect(csv_rows.first["会社名"]).to eq("Fallback Company")
  end

  it "keeps CSV export admin-only" do
    create(:document_permission)
    sign_in_as(create(:user, :external))

    get admin_document_permissions_path(format: :csv)

    expect(response).to have_http_status(:forbidden)
  end
end
