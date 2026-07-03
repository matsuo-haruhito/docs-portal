require "rails_helper"

RSpec.describe "Admin storage area usage details", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def write_storage_file(relative_path, content)
    path = Rails.root.join("storage", relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, content)
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage/docs_sites/spec-storage-usage-detail"))
    FileUtils.rm_rf(Rails.root.join("storage/imports/spec-storage-usage-detail-upload-preview"))
    FileUtils.rm_rf(Rails.root.join("storage/imports/spec-storage-usage-detail-artifact-pack"))
    FileUtils.rm_f(Rails.root.join("storage/imports/spec-storage-usage-detail-source.zip"))
    FileUtils.mkdir_p(Rails.root.join("storage/docs_sites"))
    FileUtils.mkdir_p(Rails.root.join("storage/imports"))
  end

  it "links the dashboard storage overview to docs site and import details" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Storage使用量")
    expect(response.body).to include("Docs site build detail")
    expect(response.body).to include(admin_storage_usage_docs_sites_path)
    expect(response.body).to include("Import staging detail")
    expect(response.body).to include(admin_storage_usage_imports_path)
  end

  it "shows bounded docs site detail with safe relative path previews" do
    write_storage_file("docs_sites/spec-storage-usage-detail/site-a/index.html", "site" * 512)
    write_storage_file("docs_sites/spec-storage-usage-detail/site-a/assets/app.js", "js")
    write_storage_file("docs_sites/spec-storage-usage-detail/site-b/index.html", "small")

    sign_in_as(admin_user)

    get admin_storage_usage_docs_sites_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Docs site build storage detail")
    expect(response.body).to include("storage/docs_sites/spec-storage-usage-detail")
    expect(page_text).to include("generated site directory")
    expect(page_text).to include("ファイル数: 3 件")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(response.body).not_to include("signed_url")
    expect(page_text).not_to include("cleanup 実行")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("削除")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("archive")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("retention")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("billing")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("quota")
  end

  it "shows import staging detail cues without destructive actions" do
    write_storage_file("imports/spec-storage-usage-detail-upload-preview/dry-run.json", "{}")
    write_storage_file("imports/spec-storage-usage-detail-artifact-pack/manifest.json", "{}")
    write_storage_file("imports/spec-storage-usage-detail-source.zip", "zip" * 256)

    sign_in_as(admin_user)

    get admin_storage_usage_imports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Import staging storage detail")
    expect(response.body).to include("storage/imports/spec-storage-usage-detail-upload-preview")
    expect(response.body).to include("storage/imports/spec-storage-usage-detail-artifact-pack")
    expect(response.body).to include("storage/imports/spec-storage-usage-detail-source.zip")
    expect(page_text).to include("manual upload staging")
    expect(page_text).to include("artifact staging")
    expect(page_text).to include("ZIP staging")
    expect(page_text).to include("ファイル数: 3 件")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(response.body).not_to include("signed_url")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("削除")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("archive")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("retention")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("billing")
    expect(parsed_html.css("a").map { |link| link.text.squish }).not_to include("quota")
  end

  it "shows empty states when storage area directories do not exist" do
    FileUtils.rm_rf(Rails.root.join("storage/docs_sites"))
    FileUtils.rm_rf(Rails.root.join("storage/imports"))

    sign_in_as(admin_user)

    get admin_storage_usage_docs_sites_path
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("直下項目: 0 件")
    expect(page_text).to include("Docs site build detail はありません")
    expect(response.body).not_to include(Rails.root.to_s)

    get admin_storage_usage_imports_path
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("直下項目: 0 件")
    expect(page_text).to include("Import staging detail はありません")
    expect(response.body).not_to include(Rails.root.to_s)
  end
end
