require "rails_helper"
require "fileutils"
require "json"
require "yaml"

RSpec.describe "Admin API specifications", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:build_root) { Rails.root.join("docusaurus", "build") }
  let(:site_root) { build_root.join(Admin::ApiSpecificationPage::SITE_PATH) }
  let(:site_index_path) { site_root.join("index.html") }
  let(:asset_css_path) { build_root.join("assets", "css", "api-spec-site-fixture.css") }
  let(:runtime_js_path) { build_root.join("assets", "js", "runtime~main.api-spec-fixture.js") }
  let(:build_status_marker_path) { Rails.root.join("tmp", "api_specification_build.status.json") }
  let(:build_request_marker_path) { Rails.root.join("tmp", "api_specification_build.requested") }
  let(:primary_source_pages) { Admin::ApiSpecificationPage::PRIMARY_SOURCE_PAGES }

  before do
    @original_api_specification_site_index = site_index_path.exist? ? site_index_path.read : nil
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)
  end

  after do
    restore_api_specification_site_index
    FileUtils.rm_f(asset_css_path)
    FileUtils.rm_f(runtime_js_path)
    FileUtils.rm_f(build_status_marker_path)
    FileUtils.rm_f(build_request_marker_path)
  end

  it "shows the API specification page from the admin menu" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("API仕様")
    expect(response.body).to include("主要ページとsource")
    expect(response.body).to include("表示状態はAPI仕様ページ全体のbuild結果です。")
    expect(response.body).to include("HTML確認先")
    expect(response.body).to include("Source")
    primary_source_pages.each do |source_page|
      expect(response.body).to include(source_page.label)
      expect(response.body).to include(source_page.source_path)
      expect(response.body).to include(source_page.site_path)
      expect(response.body).to include(site_admin_api_specification_path(site_path: source_page.site_path))
    end
  end

  it "keeps primary source page paths aligned with docs-src front matter slugs" do
    primary_source_pages.each do |source_page|
      source_path = Rails.root.join(source_page.source_path)
      expect(source_path).to exist, "#{source_page.source_path} is missing"

      front_matter = source_path.read.match(/\A---\n(?<yaml>.*?)\n---\n/m)
      expect(front_matter).to be_present, "#{source_page.source_path} is missing front matter"

      metadata = YAML.safe_load(front_matter[:yaml])
      expect(metadata.fetch("slug")).to eq("/#{source_page.site_path}")
    end
  end

  it "shows the current successful build status" do
    write_api_specification_site_fixture
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最新 build 成功")
    expect(response.body).to include("最終成功")
    expect(response.body).not_to include("失敗調査の入口")
    expect(response.body).not_to include("手動 build 再実行")
  end

  it "notifies the admin when a stale API specification build is enqueued" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(true)
    write_build_request_marker

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Docusaurus build を開始しました")
    expect(response.body).to include("build 待ち/実行中")
    expect(response.body).not_to include("失敗調査の入口")
  end

  it "shows a sanitized failed build status" do
    write_failed_build_marker("failed at [path] token=[FILTERED]")
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("build 失敗")
    expect(response.body).to include("failed at [path] token=[FILTERED]")
  end

  it "shows safe runbook guidance for failed API specification builds" do
    raw_failure = "failed at /app/tmp/build.log token=raw-secret stderr=#{"x" * 220}"
    write_failed_build_marker("failed at [path] token=[FILTERED]")
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("失敗調査の入口")
    expect(response.body).to include("API仕様ページとdocs-src更新確認runbook")
    expect(response.body).to include("build-docs workflow確認runbook")
    primary_source_pages.each do |source_page|
      expect(response.body).to include(source_page.source_path)
    end
    expect(response.body).to include("手動 build 再実行")
    expect(response.body).to include("API仕様ページの build を再実行")
    expect(response.body).to include("source、runtime、job / CI logs")
    expect(response.body).not_to include(raw_failure)
    expect(response.body).not_to include("raw-secret")
    expect(response.body).not_to include("/app/tmp/build.log")
  end

  it "shows when the source is newer than the rendered HTML" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HTML未生成または stale")
    expect(response.body).to include("Markdownより古い状態")
    expect(response.body).to include("手動 build 再実行")
    expect(response.body).not_to include("失敗調査の入口")
  end

  it "shows when the rendered HTML has not been generated yet" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HTML未生成または stale")
    expect(response.body).to include("Docusaurus build が必要です")
  end

  it "enqueues a manual API specification build from a failed state" do
    write_failed_build_marker("failed at [path] token=[FILTERED]")
    expect(ApiSpecificationBuildJob).to receive(:perform_later).once

    sign_in_as(admin_user)

    post retry_build_admin_api_specification_path

    expect(response).to redirect_to(admin_api_specification_path)
    expect(build_request_marker_path.exist?).to eq(true)
    follow_redirect!
    expect(response.body).to include("API仕様ページの Docusaurus build を再実行します")
  end

  it "does not enqueue a duplicate manual API specification build while one is requested" do
    write_failed_build_marker("failed at [path] token=[FILTERED]")
    write_build_request_marker
    expect(ApiSpecificationBuildJob).not_to receive(:perform_later)

    sign_in_as(admin_user)

    post retry_build_admin_api_specification_path

    expect(response).to redirect_to(admin_api_specification_path)
    follow_redirect!
    expect(response.body).to include("すでに実行中です")
  end

  it "keeps the manual API specification build retry limited to internal admins" do
    write_failed_build_marker("failed at [path] token=[FILTERED]")
    expect(ApiSpecificationBuildJob).not_to receive(:perform_later)

    sign_in_as(create(:user, :company_master_admin))

    post retry_build_admin_api_specification_path

    expect(response).to have_http_status(:forbidden)
    expect(build_request_marker_path.exist?).to eq(false)
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

  def write_failed_build_marker(message)
    FileUtils.mkdir_p(build_status_marker_path.dirname)
    File.write(
      build_status_marker_path,
      JSON.generate(status: "failed", recorded_at: Time.current.iso8601, message:)
    )
  end

  def write_build_request_marker
    FileUtils.mkdir_p(build_request_marker_path.dirname)
    File.write(build_request_marker_path, Time.current.iso8601)
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
