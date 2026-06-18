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

  def json_body
    JSON.parse(response.body)
  end

  def missing_file_for(document, file_name:, storage_key:)
    version = create(:document_version, document:)
    create(:document_file, document_version: version, file_name:, storage_key:)
  end

  def project_filter
    parsed_html.at_css(%(input[name="project_id"])) || parsed_html.at_css(%(select[name="project_id"]))
  end

  def selected_value(node)
    node&.[]("value").presence || node&.at_css("option[selected]")&.[]("value")
  end

  def clear_filter_links
    parsed_html.css(%(form[action="#{admin_missing_document_files_path}"] a[href="#{admin_missing_document_files_path}"])).select do |link|
      link.text.squish == "条件をクリア"
    end
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
    expect(clear_filter_links).to be_empty
  end

  it "does not show the clear link for blank query filters" do
    sign_in_as(admin_user)

    get admin_missing_document_files_path(document_q: "  ", file_q: "\t")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("実体ファイルの欠落は検出されていません。")
    expect(clear_filter_links).to be_empty
    expect(page_text).not_to include("条件一致欠落")
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
    expect(response.body).to include("この詳細一覧は全体の実体欠落の先頭100件までを表示します。")
    expect(response.body).to include("全体の実体欠落は101件ありますが、表示中は先頭100件までです。")
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
    expect(page_text).to include("条件一致欠落は現在の絞り込みに合う全件数、表示中は詳細一覧に出している先頭100件までの件数です。")
    expect(page_text).to include("この詳細一覧は条件一致欠落の先頭100件までを表示します。")
    expect(page_text).to include("条件一致欠落は101件ありますが、表示中は先頭100件までです。")
    expect(page_text).to include("自動修復、削除、再import、CSV export は行いません")

    table_text = parsed_html.at_css("table").text.squish
    expect(table_text).to include("Missing Project")
    expect(table_text).not_to include("Other Project")

    form = parsed_html.at_css("form[action='#{admin_missing_document_files_path}']")
    expect(form).to be_present
    expect(project_filter).to be_present
    expect(selected_value(project_filter)).to eq(project.id.to_s)
    expect(response.body).to include("案件コード・案件名で検索")
    expect(response.body).to include(project_search_admin_missing_document_files_path(format: :json))
    expect(response.body).to include(selected_project_admin_missing_document_files_path(format: :json))
    expect(form.at_css("input[name='document_q']")["value"]).to be_blank
    expect(form.at_css("input[name='file_q']")["value"]).to be_blank
    expect(clear_filter_links.size).to eq(1)
    expect(parsed_html.css("table tbody tr").size).to eq(100)
  end

  it "returns bounded remote project search options and selected project labels" do
    sign_in_as(admin_user)

    matching_project = create(:project, code: "OPS", name: "Operations Search")
    create(:project, code: "FIN", name: "Finance Search")

    get project_search_admin_missing_document_files_path(format: :json), params: { q: "ops" }

    expect(response).to have_http_status(:ok)
    project_options = json_body.fetch("options")
    expect(project_options).to contain_exactly(
      include("value" => matching_project.id, "text" => "OPS / Operations Search")
    )

    get selected_project_admin_missing_document_files_path(format: :json), params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => project.id, "text" => "MISS / Missing Project")
  end

  it "normalizes long project search queries before matching" do
    sign_in_as(admin_user)

    search_prefix = "A" * Admin::MissingDocumentFilesController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    matching_project = create(:project, code: "LONG", name: search_prefix)
    create(:project, code: "TAIL", name: "overflow-only-project")

    get project_search_admin_missing_document_files_path(format: :json), params: { q: "  #{search_prefix}overflow-only-project  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => matching_project.id, "text" => "LONG / #{search_prefix}")
    )
  end

  it "restores selected projects outside the search result limit and returns nil for missing ids" do
    sign_in_as(admin_user)

    22.times do |index|
      create(:project, code: format("AAA%02d", index), name: "Limited Search #{index}")
    end
    project_outside_search_limit = create(:project, code: "ZZZ99", name: "Restored Outside Limit")

    get project_search_admin_missing_document_files_path(format: :json), params: { q: "Limited Search" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::MissingDocumentFilesController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options")).not_to include(
      include("value" => project_outside_search_limit.id)
    )

    get selected_project_admin_missing_document_files_path(format: :json), params: { id: project_outside_search_limit.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => project_outside_search_limit.id,
      "text" => "ZZZ99 / Restored Outside Limit"
    )

    get selected_project_admin_missing_document_files_path(format: :json), params: { id: Project.maximum(:id).to_i + 1000 }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "bounds missing file project search result counts" do
    sign_in_as(admin_user)

    22.times do |index|
      create(:project, code: format("MISS%02d", index), name: "Missing Search #{index}")
    end

    get project_search_admin_missing_document_files_path(format: :json), params: { q: "Missing Search" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("options").size).to eq(Admin::MissingDocumentFilesController::PROJECT_SEARCH_LIMIT)
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
    expect(clear_filter_links.size).to eq(1)

    get admin_missing_document_files_path(document_q: "release-checklist")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Release Checklist")
    expect(page_text).not_to include("Safety Runbook")
    expect(clear_filter_links.size).to eq(1)

    get admin_missing_document_files_path(file_q: "manuals/safety")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Safety Runbook")
    expect(page_text).not_to include("Release Checklist")
    expect(clear_filter_links.size).to eq(1)

    get admin_missing_document_files_path(file_q: "release.csv")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Release Checklist")
    expect(page_text).not_to include("Safety Runbook")
    expect(clear_filter_links.size).to eq(1)
  end

  it "applies project, document, and file filters together as an AND condition" do
    matching_document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    same_project_wrong_file = create(:document, project:, title: "Safety Checklist", slug: "safety-checklist")
    wrong_project_document = create(:document, project: other_project, title: "Safety Runbook", slug: "safety-runbook-other-project")
    wrong_document = create(:document, project:, title: "Release Checklist", slug: "release-checklist")
    missing_file_for(matching_document, file_name: "handoff.pdf", storage_key: "manuals/safety/handoff.pdf")
    missing_file_for(same_project_wrong_file, file_name: "safety-notes.pdf", storage_key: "manuals/safety/notes.pdf")
    missing_file_for(wrong_project_document, file_name: "handoff.pdf", storage_key: "manuals/safety/handoff-copy.pdf")
    missing_file_for(wrong_document, file_name: "handoff.pdf", storage_key: "manuals/release/handoff.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(project_id: project.id, document_q: "safety", file_q: "handoff")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("登録ファイル数: 4")
    expect(page_text).to include("全体の実体欠落: 4")
    expect(page_text).to include("条件一致欠落: 1")
    expect(page_text).to include("表示中: 1")
    expect(page_text).to include("条件: 案件=Missing Project / 文書=safety / ファイル=handoff")
    expect(page_text).to include("条件一致欠落は現在の絞り込みに合う全件数、表示中は詳細一覧に出している先頭100件までの件数です。")
    expect(page_text).to include("自動修復、削除、再import、CSV export は行いません")
    expect(response.body).not_to include("削除する")
    expect(response.body).not_to include("再importを実行")
    expect(response.body).not_to include("CSVを出力")

    table_text = parsed_html.at_css("table").text.squish
    expect(table_text).to include("Missing Project")
    expect(table_text).to include("Safety Runbook")
    expect(table_text).to include("handoff.pdf")
    expect(table_text).not_to include("Safety Checklist")
    expect(table_text).not_to include("Other Project")
    expect(table_text).not_to include("Release Checklist")

    form = parsed_html.at_css("form[action='#{admin_missing_document_files_path}']")
    expect(selected_value(project_filter)).to eq(project.id.to_s)
    expect(form.at_css("input[name='document_q']")["value"]).to eq("safety")
    expect(form.at_css("input[name='file_q']")["value"]).to eq("handoff")
    expect(clear_filter_links.size).to eq(1)
  end

  it "drops invalid project ids while preserving other filters" do
    document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    missing_file_for(document, file_name: "handoff.pdf", storage_key: "manuals/safety/handoff.pdf")
    invalid_project_id = Project.maximum(:id).to_i + 1000

    sign_in_as(admin_user)

    get admin_missing_document_files_path(project_id: invalid_project_id, document_q: "safety", file_q: "handoff")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("全体の実体欠落: 1")
    expect(page_text).to include("条件一致欠落: 1")
    expect(page_text).to include("表示中: 1")
    expect(page_text).to include("条件: 文書=safety / ファイル=handoff")
    expect(page_text).not_to include("案件=#{invalid_project_id}")
    expect(page_text).not_to include("案件=")
    expect(selected_value(project_filter)).to be_blank
    expect(page_text).to include("Safety Runbook")
    expect(response.body).to include("handoff.pdf")
    expect(response.body).not_to include("削除する")
    expect(response.body).not_to include("再importを実行")
    expect(response.body).not_to include("CSVを出力")
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
    expect(page_text).to include("表示中は0件で、全体欠落が解消されたわけではありません。")
    expect(page_text).not_to include("実体ファイルの欠落は検出されていません。")
    expect(clear_filter_links.size).to eq(1)

    DocumentFile.delete_all

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("全体の実体欠落: 0")
    expect(response.body).to include("実体ファイルの欠落は検出されていません。")
    expect(clear_filter_links).to be_empty
  end
end
