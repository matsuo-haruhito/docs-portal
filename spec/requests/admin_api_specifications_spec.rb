require "rails_helper"
require "fileutils"

RSpec.describe "Admin API specifications", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:build_root) { Rails.root.join("docusaurus", "build") }
  let(:site_root) { build_root.join(Admin::ApiSpecificationPage::SITE_PATH) }
  let(:site_index_path) { site_root.join("index.html") }
  let(:asset_css_path) { build_root.join("assets", "css", "api-spec-site-fixture.css") }
  let(:runtime_js_path) { build_root.join("assets", "js", "runtime~main.api-spec-fixture.js") }

  before do
    @original_api_specification_site_index = site_index_path.exist? ? site_index_path.read : nil
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)
  end

  after do
    restore_api_specification_site_index
    FileUtils.rm_f(asset_css_path)
    FileUtils.rm_f(runtime_js_path)
  end

  it "shows the API specification page from the admin menu" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("API仕様")
    expect(response.body).to include("docs-src/api-specification.md")
    expect(response.body).to include("単体ファイルアップロードAPI")
    expect(response.body).to include("client-file-upload-api")
  end

  it "notifies the admin when a stale API specification build is enqueued" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(true)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Docusaurus build を開始しました")
  end

  it "renders the built API specification HTML through the admin site route" do
    write_api_specification_site_fixture
    sign_in_as(admin_user)

    get site_admin_api_specification_path(site_path: "#{Admin::ApiSpecificationPage::SITE_PATH}/index.html")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("API specification site fixture")
    expect(response.body).to include(site_admin_api_specification_path(site_path: "assets/css/api-spec-site-fixture.css"))
  end

  it "serves built API specification assets with private immutable cache headers" do
    write_api_specification_site_fixture
    sign_in_as(admin_user)

    get site_admin_api_specification_path(site_path: "assets/css/api-spec-site-fixture.css")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).to include("color: #334155")
    expect(response.headers["Cache-Control"].split(/,\s*/)).to include("private", "max-age=31536000", "immutable")
  end

  it "rewrites Docusaurus runtime public paths to the admin site route" do
    write_api_specification_site_fixture
    sign_in_as(admin_user)

    get site_admin_api_specification_path(site_path: "assets/js/runtime~main.api-spec-fixture.js")

    proxied_site_root = site_admin_api_specification_path(site_path: "__docs_portal_asset__").delete_suffix("__docs_portal_asset__")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to end_with("javascript")
    expect(response.body).to include("f.p=#{proxied_site_root.dump}")
    expect(response.body).to include("f.p+f.u(r)")
  end

  it "returns not found when the API specification build entry is missing" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    sign_in_as(admin_user)

    get site_admin_api_specification_path(site_path: Admin::ApiSpecificationPage::SITE_PATH)

    expect(response).to have_http_status(:not_found)
  end

  it "keeps the admin site route limited to internal admins" do
    write_api_specification_site_fixture

    sign_in_as(create(:user, :company_master_admin))
    get site_admin_api_specification_path(site_path: Admin::ApiSpecificationPage::SITE_PATH)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get site_admin_api_specification_path(site_path: Admin::ApiSpecificationPage::SITE_PATH)
    expect(response).to have_http_status(:forbidden)
  end

  def write_api_specification_site_fixture
    FileUtils.mkdir_p(site_root)
    File.write(
      site_index_path,
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <link rel="stylesheet" href="/assets/css/api-spec-site-fixture.css">
            <script src="/assets/js/runtime~main.api-spec-fixture.js"></script>
          </head>
          <body>
            <h1>API specification site fixture</h1>
          </body>
        </html>
      HTML
    )

    FileUtils.mkdir_p(asset_css_path.dirname)
    File.write(asset_css_path, "body { color: #334155; }")

    FileUtils.mkdir_p(runtime_js_path.dirname)
    File.write(runtime_js_path, '(()=>{f.p="/";var d=f.p+f.u(r);return d;})();')
  end

  def restore_api_specification_site_index
    if @original_api_specification_site_index
      FileUtils.mkdir_p(site_root)
      File.write(site_index_path, @original_api_specification_site_index)
    else
      FileUtils.rm_f(site_index_path)
      FileUtils.rmdir(site_root) if site_root.exist? && site_root.children.empty?
    end
  end
end
