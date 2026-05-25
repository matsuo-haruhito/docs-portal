require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "External document access boundaries", type: :request do
  let(:external_user) { create(:user, :external) }
  let(:member_project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Member Project") }
  let(:other_project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def result_titles
    parsed_html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  def page_text
    parsed_html.text
  end

  def write_site_file(version, relative_path, content)
    path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  before do
    create(:project_membership, project: member_project, user: external_user)
  end

  it "lists only projects the external user belongs to" do
    sign_in_as(external_user)

    get projects_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Member Project")
    expect(response.body).not_to include("Other Project")
  end

  it "shows only permitted documents on member project pages and document index" do
    permitted_document = create(:document, project: member_project, title: "公開資料", slug: "permitted-doc")
    no_permission_document = create(:document, project: member_project, title: "権限なし資料", slug: "no-permission-doc")
    internal_document = create(:document, project: member_project, title: "社内限定資料", slug: "internal-doc", visibility_policy: :internal_only)
    other_company_document = create(:document, project: member_project, title: "他社向け資料", slug: "other-company-doc")
    create(:document_permission, document: permitted_document, company: external_user.company, access_level: :view)
    create(:document_permission, document: other_company_document, company: create(:company), access_level: :view)

    sign_in_as(external_user)

    get project_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("公開資料")
    expect(page_text).not_to include("権限なし資料")
    expect(page_text).not_to include("社内限定資料")
    expect(page_text).not_to include("他社向け資料")

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("公開資料")

    get project_document_path(member_project, permitted_document.slug)
    expect(response).to have_http_status(:ok)

    get project_document_path(member_project, no_permission_document.slug)
    expect(response).to have_http_status(:forbidden)

    get project_document_path(member_project, internal_document.slug)
    expect(response).to have_http_status(:forbidden)

    get project_document_path(member_project, other_company_document.slug)
    expect(response).to have_http_status(:forbidden)
  end

  it "uses project codes, document slugs, and public ids across external viewing routes" do
    document = create(
      :document,
      project: member_project,
      title: "識別子確認資料",
      slug: "identifier-route-doc",
      visibility_policy: :public_with_login
    )
    version = create(
      :document_version,
      document:,
      version_label: "v2.4.0",
      status: :published,
      site_build_path: "docs/identifier-route-doc"
    )
    document.update!(latest_version: version)
    file = DocumentFile.create!(
      document_version: version,
      file_name: "identifier-route-doc.pdf",
      content_type: "application/pdf",
      storage_key: "spec/#{SecureRandom.hex(8)}-identifier-route-doc.pdf",
      file_size: 10,
      scan_status: :scan_clean
    )
    create(:document_permission, document:, company: external_user.company, access_level: :download)
    write_site_file(version, "docs/identifier-route-doc/index.html", "<html><body><h1>Identifier Route Doc</h1></body></html>")
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, "%PDF-1.4")

    sign_in_as(external_user)

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(project_document_path(member_project, document.slug))

    get project_document_path(member_project, document.slug)
    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(project_path(member_project))
    expect(link_hrefs).to include(project_documents_path(member_project))
    expect(link_hrefs).to include(document_version_path(version))
    expect(link_hrefs).to include(document_file_path(file, disposition: "download"))
    expect(parsed_html.at_css("iframe.site-viewer-frame")["src"]).to include("version_id=#{version.public_id}")

    get document_version_path(version)
    expect(response).to have_http_status(:ok)
    expect(request.path).to eq("/document_versions/#{version.public_id}")
    expect(page_text).to include("v2.4.0")

    get document_file_path(file)
    expect(response).to have_http_status(:ok)
    expect(request.path).to eq("/document_files/#{file.public_id}")
    expect(response.media_type).to eq("application/pdf")
  ensure
    FileUtils.rm_f(file.absolute_path) if file&.id
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end

  it "hides archived documents from external routes until an admin restores them" do
    admin_user = create(:user, :internal)
    archived_document = create(:document, project: member_project, title: "運用手順書", slug: "ops-manual")
    published_version = create(:document_version, document: archived_document, version_label: "v1.0.0", status: :published)
    archived_document.update!(latest_version: published_version)
    create(:document_permission, document: archived_document, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get project_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("運用手順書")

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用手順書")

    get project_document_path(member_project, archived_document.slug)
    expect(response).to have_http_status(:ok)

    sign_in_as(admin_user)

    patch archive_admin_document_path(archived_document)
    expect(response).to redirect_to(admin_documents_path)
    expect(archived_document.reload).to be_archived

    sign_in_as(external_user)

    get project_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("運用手順書")

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).not_to include("運用手順書")

    get project_document_path(member_project, archived_document.slug)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(admin_user)

    patch restore_admin_document_path(archived_document)
    expect(response).to redirect_to(admin_documents_path)
    expect(archived_document.reload).not_to be_archived

    sign_in_as(external_user)

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用手順書")

    get project_document_path(member_project, archived_document.slug)
    expect(response).to have_http_status(:ok)
  end

  it "allows public_with_login documents without document permissions but still protects downloads" do
    document = create(:document, project: member_project, title: "ログイン公開資料", slug: "login-visible-doc", visibility_policy: :public_with_login)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      site_build_path: "docs/login-visible-doc"
    )
    document.update!(latest_version: version)
    file = DocumentFile.create!(
      document_version: version,
      file_name: "login-visible.pdf",
      content_type: "application/pdf",
      storage_key: "spec/#{SecureRandom.hex(8)}-login-visible.pdf",
      file_size: 10,
      scan_status: :scan_clean
    )
    write_site_file(version, "docs/login-visible-doc/index.html", "<html><body><h1>Login Visible Doc</h1></body></html>")
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, "%PDF-1.4")

    sign_in_as(external_user)

    get project_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("ログイン公開資料")

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("ログイン公開資料")

    get project_document_path(member_project, document.slug)
    expect(response).to have_http_status(:ok)

    get site_document_version_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Login Visible Doc")

    get document_file_path(file)
    expect(response).to have_http_status(:forbidden)

    create(:document_permission, document:, company: external_user.company, access_level: :download)

    get document_file_path(file)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
  ensure
    FileUtils.rm_f(file.absolute_path) if file&.id
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end

  it "treats company_master_admin users like external users for document visibility boundaries" do
    manager = create(:user, :external, user_type: :company_master_admin, company: external_user.company)
    create(:project_membership, project: member_project, user: manager)

    public_document = create(:document, project: member_project, title: "ログイン公開管理資料", slug: "manager-public-doc", visibility_policy: :public_with_login)
    restricted_document = create(:document, project: member_project, title: "権限付き資料", slug: "manager-restricted-doc")
    internal_document = create(:document, project: member_project, title: "社内専用資料", slug: "manager-internal-doc", visibility_policy: :internal_only)
    create(:document_permission, document: restricted_document, company: manager.company, access_level: :view)

    sign_in_as(manager)

    get project_documents_path(member_project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("ログイン公開管理資料", "権限付き資料")
    expect(result_titles).not_to include("社内専用資料")

    get project_document_path(member_project, public_document.slug)
    expect(response).to have_http_status(:ok)

    get project_document_path(member_project, restricted_document.slug)
    expect(response).to have_http_status(:ok)

    get project_document_path(member_project, internal_document.slug)
    expect(response).to have_http_status(:forbidden)
  end

  it "forbids direct access to non-member project documents and files" do
    other_document = create(:document, project: other_project, title: "他案件資料", slug: "other-project-doc")
    other_version = create(:document_version, document: other_document, version_label: "v1.0.0")
    other_file = DocumentFile.create!(
      document_version: other_version,
      file_name: "other.pdf",
      content_type: "application/pdf",
      storage_key: "spec/#{SecureRandom.hex(8)}-other.pdf",
      file_size: 10
    )

    sign_in_as(external_user)

    get project_document_path(other_project, other_document.slug)
    expect(response).to have_http_status(:forbidden)

    get document_file_path(other_file)
    expect(response).to have_http_status(:forbidden)
  end

  it "forbids draft and archived document versions for external users" do
    document = create(:document, project: member_project, title: "版管理資料", slug: "versioned-doc")
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    published_version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    draft_version = create(:document_version, document:, version_label: "v1.1.0", status: :draft)
    archived_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)

    sign_in_as(external_user)

    get project_document_path(member_project, document.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(published_version.version_label)
    expect(response.body).not_to include(draft_version.version_label)
    expect(response.body).not_to include(archived_version.version_label)

    get site_document_version_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get site_document_version_path(archived_version)
    expect(response).to have_http_status(:forbidden)
  end

  it "checks direct document site html and asset access with document permissions" do
    document = create(:document, project: member_project, title: "サイト資料", slug: "site-doc")
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      site_build_path: "docs/site-doc"
    )
    write_site_file(version, "docs/site-doc/index.html", "<html><body><h1>Site Doc</h1></body></html>")
    write_site_file(version, "assets/css/app.css", "body{color:#333;}")

    sign_in_as(external_user)

    get site_document_version_path(version)
    expect(response).to have_http_status(:forbidden)

    get site_document_version_path(version, site_path: "assets/css/app.css")
    expect(response).to have_http_status(:forbidden)

    create(:document_permission, document:, company: external_user.company, access_level: :view)

    get site_document_version_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Site Doc")

    get site_document_version_path(version, site_path: "assets/css/app.css")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
  ensure
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end
end
