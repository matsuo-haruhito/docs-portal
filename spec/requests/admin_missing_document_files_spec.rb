require "rails_helper"

RSpec.describe "Admin missing document files", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }
  let(:project) { create(:project, code: "MISS", name: "Missing Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def missing_file_for(document, file_name:, storage_key:)
    version = create(:document_version, document:)
    create(:document_file, document_version: version, file_name:, storage_key:)
  end

  it "lets admins open missing file details from the dashboard" do
    file = create(
      :document_file,
      document_version: version,
      file_name: "missing-detail.txt",
      storage_key: "spec/admin-missing-document-files/missing-detail.txt"
    )

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("欠落ファイル詳細を開く")
    expect(response.body).to include(admin_missing_document_files_path)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("欠落文書ファイル詳細")
    expect(response.body).to include(version.document.project.name)
    expect(response.body).to include(version.document.title)
    expect(response.body).to include(version.version_label)
    expect(response.body).to include(file.file_name)
    expect(response.body).to include(file.storage_key)
    expect(response.body).to include("storage/document_files/spec/admin-missing-document-files/missing-detail.txt")
    expect(response.body).not_to include(file.absolute_path.to_s)
    expect(response.body).not_to include(Rails.root.to_s)
  end

  it "keeps the details page admin-only" do
    sign_in_as(create(:user, :company_master_admin))
    get admin_missing_document_files_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_missing_document_files_path
    expect(response).to have_http_status(:forbidden)
  end

  it "shows an empty state when no document files are missing" do
    sign_in_as(admin_user)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("実体ファイルの欠落は検出されていません。")
    expect(response.body).not_to include("Expected path")
  end

  it "bounds the detail list and does not expose destructive actions" do
    101.times do |index|
      create(
        :document_file,
        document_version: version,
        file_name: "missing-detail-#{index}.txt",
        storage_key: "spec/admin-missing-document-files/limited/missing-detail-#{index}.txt"
      )
    end

    sign_in_as(admin_user)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("この詳細一覧は先頭100件まで表示します。")
    expect(response.body).to include("missing-detail-0.txt")
    expect(response.body).to include("missing-detail-99.txt")
    expect(response.body).not_to include("missing-detail-100.txt")
    expect(response.body).not_to include("削除する")
    expect(response.body).not_to include("再importを実行")
    expect(response.body).not_to include("CSVを出力")
  end

  it "shows filter controls and keeps project-filtered missing file rows within the display limit" do
    matching_document = create(:document, project:, title: "Operations Runbook", slug: "ops-runbook")
    other_document = create(:document, project: other_project, title: "Other Runbook", slug: "other-runbook")
    101.times do |index|
      missing_file_for(
        matching_document,
        file_name: "missing-#{index}.pdf",
        storage_key: "imports/missing-#{index}.pdf"
      )
    end
    missing_file_for(other_document, file_name: "other.pdf", storage_key: "other/missing.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("登録ファイル数: 102")
    expect(page_text).to include("全体の実体欠落: 102")
    expect(page_text).to include("条件一致欠落: 101")
    expect(page_text).to include("表示中: 100")
    expect(page_text).to include("条件一致欠落件数が100件を超えています")
    expect(page_text).to include("自動修復、削除、再import、CSV export は行いません")

    table_text = parsed_html.at_css("table").text.squish
    expect(table_text).to include("Missing Project")
    expect(table_text).not_to include("Other Project")

    form = parsed_html.at_css("form[action='#{admin_missing_document_files_path}']")
    expect(form).to be_present
    expect(form.at_css("select[name='project_id'] option[selected]")["value"]).to eq(project.id.to_s)
    expect(form.at_css("input[name='document_q']")["value"]).to be_blank
    expect(form.at_css("input[name='file_q']")["value"]).to be_blank
    expect(parsed_html.at_css("a[href='#{admin_missing_document_files_path}']").text).to include("条件をクリア")
    expect(parsed_html.css("table tbody tr").size).to eq(100)
  end

  it "filters missing files by document title, slug, storage key, and file name fragments" do
    runbook_document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    checklist_document = create(:document, project:, title: "Release Checklist", slug: "release-checklist")
    missing_file_for(runbook_document, file_name: "safety.pdf", storage_key: "manuals/safety.pdf")
    missing_file_for(checklist_document, file_name: "release.csv", storage_key: "archives/release.csv")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(document_q: "safety")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Safety Runbook")
    expect(page_text).not_to include("Release Checklist")
    expect(page_text).to include("条件一致欠落: 1")

    get admin_missing_document_files_path(document_q: "release-checklist")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Release Checklist")
    expect(page_text).not_to include("Safety Runbook")

    get admin_missing_document_files_path(file_q: "manuals/safety")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Safety Runbook")
    expect(page_text).not_to include("Release Checklist")

    get admin_missing_document_files_path(file_q: "release.csv")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Release Checklist")
    expect(page_text).not_to include("Safety Runbook")
  end

  it "distinguishes no missing files from no matching filtered results" do
    document = create(:document, project:, title: "Visible Manual", slug: "visible-manual")
    missing_file_for(document, file_name: "visible.pdf", storage_key: "visible.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(document_q: "not-found")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("全体の実体欠落: 1")
    expect(page_text).to include("条件一致欠落: 0")
    expect(page_text).to include("条件に一致する欠落ファイルはありません。全体では1件の実体欠落があります。")
    expect(page_text).not_to include("実体ファイルの欠落は検出されていません。")

    DocumentFile.delete_all

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("全体の実体欠落: 0")
    expect(page_text).to include("実体ファイルの欠落は検出されていません。")
  end
end
