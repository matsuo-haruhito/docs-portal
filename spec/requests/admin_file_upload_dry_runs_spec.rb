require "rails_helper"

RSpec.describe "Admin file upload dry runs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "FILEUI", name: "File UI Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def parsed_json
    JSON.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def listed_dry_run_ids
    parsed_html.css("table tbody tr td:nth-child(2) code").map { _1.text.squish }
  end

  def heading_texts
    parsed_html.css("h1, h2, h3").map { _1.text.squish }.reject(&:empty?)
  end

  def link_href(label)
    parsed_html.css("a").find { _1.text.squish == label }&.[]("href")
  end

  def submit_button_texts(action)
    parsed_html.css(%(form[action="#{action}"] button, form[action="#{action}"] input[type="submit"])).map do |node|
      node["value"].presence || node.text.squish
    end
  end

  it "lists only manual upload dry-runs with detail links and safe preview columns" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run
    zip_dry_run = create_file_upload_dry_run(
      import_mode: :zip,
      result_json: {
        "file_upload_preview" => {
          "source_name" => "zip-source",
          "relative_path" => "zip/README.md",
          "source_path" => "C:/work/zip-source-path/README.md",
          "content_hash" => "ziphash"
        }
      }
    )

    get admin_file_upload_dry_runs_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("単体ファイルアップロードdry-run一覧")
    expect(page_text).to include("API から作成された manual_upload dry-run を後から確認するための一覧です。ZIP / Git import dry-run は表示しません。")
    expect(page_text).to include(dry_run.public_id)
    expect(response.body).to include(admin_file_upload_dry_run_path(dry_run))
    expect(page_text).to include("FILEUI / File UI Project")
    expect(page_text).to include("local-folder-sync")
    expect(page_text).to include("docs/README.md")
    expect(page_text).to include("abc123contenthash")
    expect(page_text).not_to include("C:/work/customer-docs/docs/README.md")
    expect(page_text).not_to include(zip_dry_run.public_id)
    expect(page_text).not_to include("zip-source")
  end

  it "keeps filter labels and safe metadata guidance close to their controls" do
    sign_in_as(admin_user)

    get admin_file_upload_dry_runs_path

    expect(response).to have_http_status(:ok)
    filter_form = parsed_html.at_css("form.filters")
    expect(filter_form).to be_present

    aggregate_failures do
      expect(filter_form.css(".field").map { _1.text.squish }).to include(
        include("dry-run ID"),
        include("同期元名・取り込み先path・content hash"),
        include("案件"),
        include("状態")
      )
      expect(filter_form.at_css("input[name='dry_run_id']")&.[]("placeholder")).to eq("公開ID (例: idry...)")
      expect(filter_form.at_css("input[name='q']")&.[]("placeholder")).to eq("同期元名・relative path・content hash")

      dry_run_id_group = filter_form.css(".field").find { _1.at_css("input[name='dry_run_id']") }
      expect(dry_run_id_group.text.squish).to include("dry-run の公開IDで完全一致検索します。")

      query_group = filter_form.css(".field").find { _1.at_css("input[name='q']") }
      expect(query_group.text.squish).to include("検索対象: 同期元名、取り込み先 relative path、content hash。")
      expect(query_group.text.squish).to include("クライアント source path は検索対象外です。")
      expect(page_text).to include("案件コード・案件名で検索できます。選択済み案件は候補上限外でも復元します。")
      expect(page_text).to include("同期元名・取り込み先path・content hash 検索は表示中の safe metadata だけを対象にし、クライアント source path は検索対象に含めません。")
    end
  end

  it "searches project filter options by code and name with a bounded result set" do
    sign_in_as(admin_user)
    matching_projects = 25.times.map do |index|
      create(:project, code: format("REMOTE%02d", index), name: "Remote Search Project #{index}")
    end
    create(:project, code: "OTHER", name: "Unrelated Project")

    get project_search_admin_file_upload_dry_runs_path(format: :json), params: { q: "remote search" }

    expect(response).to have_http_status(:ok)
    options = parsed_json.fetch("options")
    expect(options.size).to eq(Admin::FileUploadDryRunsController::PROJECT_SEARCH_LIMIT)
    expect(options.first).to include(
      "value" => matching_projects.first.id,
      "text" => "REMOTE00 / Remote Search Project 0"
    )
    expect(options.map { _1.fetch("text") }).not_to include("OTHER / Unrelated Project")
  end

  it "returns a selected project option and nil for a missing project" do
    sign_in_as(admin_user)

    get selected_project_admin_file_upload_dry_runs_path(format: :json), params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(parsed_json.fetch("option")).to include(
      "value" => project.id,
      "text" => "FILEUI / File UI Project"
    )

    get selected_project_admin_file_upload_dry_runs_path(format: :json), params: { id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json.fetch("option")).to be_nil
  end

  it "restores a selected project label even when it is outside the search limit" do
    sign_in_as(admin_user)
    25.times { |index| create(:project, code: format("AAA%02d", index), name: "Early Project #{index}") }
    late_project = create(:project, code: "ZZZ99", name: "Limit Outside Project")
    create_file_upload_dry_run(project_override: late_project)

    get admin_file_upload_dry_runs_path, params: { project_id: late_project.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("ZZZ99 / Limit Outside Project")
    expect(listed_dry_run_ids.size).to eq(1)
  end

  it "keeps invalid project ids unfiltered like the current contract" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run

    get admin_file_upload_dry_runs_path, params: { project_id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([dry_run.public_id])
    expect(page_text).not_to include("絞り込み解除")
  end

  it "explains the initial empty manual upload dry-run list" do
    sign_in_as(admin_user)

    get admin_file_upload_dry_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("manual_upload dry-runはまだ作成されていません。")
    expect(page_text).to include("file_uploads APIで作成されたdry-runは、ここから後追い確認できます。")
    expect(page_text).to include("ZIP / Git import dry-runとartifact import dry-runはこの一覧には表示されません。")
    expect(page_text).not_to include("dry-run ID、同期元名・取り込み先path・content hash、案件、状態の条件を見直すか")
  end

  it "explains filtered zero results and keeps the reset link close to the empty state" do
    sign_in_as(admin_user)
    create_file_upload_dry_run

    get admin_file_upload_dry_runs_path, params: { dry_run_id: "idry-missing", q: "missing-source", status: "failed" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("条件に一致するmanual_upload dry-runはありません。")
    expect(page_text).to include("dry-run ID、同期元名・取り込み先path・content hash、案件、状態の条件を見直すか、絞り込み解除で一覧に戻してください。")
    expect(page_text).to include("ZIP / Git import dry-runとartifact import dry-runはこの一覧には表示されません。")
    expect(link_href("絞り込み解除")).to eq(admin_file_upload_dry_runs_path)
    expect(page_text).not_to include("local-folder-sync")
  end

  it "filters manual upload dry-runs by safe source metadata" do
    sign_in_as(admin_user)
    source_match = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "quarterly-source",
          "relative_path" => "docs/source.md",
          "source_path" => "C:/private/source-only/source.md",
          "content_hash" => "sourcehash"
        }
      }
    )
    path_match = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "path-sync",
          "relative_path" => "guides/manual-upload/search-target.md",
          "source_path" => "C:/private/path-only/search-target.md",
          "content_hash" => "pathhash"
        }
      }
    )
    hash_match = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "hash-sync",
          "relative_path" => "docs/hash.md",
          "source_path" => "C:/private/hash-only/hash.md",
          "content_hash" => "abc-hash-target-999"
        }
      }
    )
    raw_source_path_only = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "raw-hidden-sync",
          "relative_path" => "docs/raw-hidden.md",
          "source_path" => "C:/private/raw-source-only/secret.md",
          "content_hash" => "rawhiddenhash"
        }
      }
    )
    create_file_upload_dry_run(
      import_mode: :zip,
      result_json: {
        "file_upload_preview" => {
          "source_name" => "quarterly-source",
          "relative_path" => "guides/manual-upload/search-target.md",
          "source_path" => "C:/private/zip/search-target.md",
          "content_hash" => "abc-hash-target-999"
        }
      }
    )

    get admin_file_upload_dry_runs_path, params: { q: "quarterly" }
    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([source_match.public_id])
    expect(page_text).to include("同期元名・取り込み先path・content hash 検索は表示中の safe metadata だけを対象にし、クライアント source path は検索対象に含めません。")

    get admin_file_upload_dry_runs_path, params: { q: "manual-upload/search" }
    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([path_match.public_id])

    get admin_file_upload_dry_runs_path, params: { q: "HASH-TARGET" }
    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([hash_match.public_id])

    get admin_file_upload_dry_runs_path, params: { q: "raw-source-only" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するmanual_upload dry-runはありません。")
    expect(page_text).to include("dry-run ID、同期元名・取り込み先path・content hash、案件、状態の条件を見直すか")
    expect(listed_dry_run_ids).to be_empty
    expect(page_text).not_to include(raw_source_path_only.public_id)
  end

  it "filters manual upload dry-runs by id, project, status, and safe metadata query together" do
    sign_in_as(admin_user)
    other_project = create(:project, code: "OTHER", name: "Other Project")
    target = create_file_upload_dry_run(
      status: :failed,
      project_override: other_project,
      result_json: {
        "file_upload_preview" => {
          "source_name" => "target-sync",
          "relative_path" => "docs/target.md",
          "content_hash" => "targethash"
        }
      }
    )
    create_file_upload_dry_run(status: :failed)
    create_file_upload_dry_run(status: :analyzed, project_override: other_project)

    get admin_file_upload_dry_runs_path, params: { dry_run_id: target.public_id, project_id: other_project.id, status: "failed", q: "target" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(target.public_id)
    expect(page_text).to include("target-sync")
    expect(page_text).to include("絞り込み解除")
    expect(page_text).not_to include("local-folder-sync")
  end

  it "shows a manual upload dry-run with file metadata and preview without exposing raw source path" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run(
      warnings_json: ["hash warning"],
      errors_json: ["manifest error"]
    )

    get admin_file_upload_dry_run_path(dry_run)

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("単体ファイルアップロードdry-run", "取り込み概要", "TreeViewプレビュー")
    expect(page_text).to include("FILEUI / File UI Project")
    expect(page_text).to include(dry_run.public_id)
    expect(page_text).to include("apply 前の確認順や API 入口の見分け方")
    expect(link_href("internal upload API dry-run / apply runbook")).to eq("https://github.com/matsuo-haruhito/docs-portal/blob/main/docs/internal%20upload%20API%20dry-run・apply運用runbook.md")
    expect(page_text).to include("local-folder-sync")
    expect(page_text).to include("docs/README.md")
    expect(page_text).to include("raw source path は画面に表示しません")
    expect(page_text).to include("relative path と content hash")
    expect(page_text).not_to include("C:/work/customer-docs/docs/README.md")
    expect(page_text).not_to include("customer-docs")
    expect(page_text).to include("abc123contenthash")
    expect(page_text).to include("file-v1")
    expect(page_text).to include("hash warning")
    expect(page_text).to include("manifest error")
    expect(submit_button_texts(admin_file_upload_dry_run_path(dry_run))).to include("この内容で取り込む")
  end

  it "confirms an analyzed dry-run and dispatches the importer" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run(
      result_json: {
        "artifact_root" => "/tmp/file-upload-artifact",
        "manifest_path" => "/tmp/file-upload-artifact/manifest.json"
      }
    )
    publish_job = double("publish_job", log_message: "started")
    allow(publish_job).to receive(:update!)
    importer = double("document_importer", call: publish_job)

    expect(DocumentImporter).to receive(:new).with(
      artifact_root: "/tmp/file-upload-artifact",
      manifest_path: "/tmp/file-upload-artifact/manifest.json",
      actor: admin_user
    ).and_return(importer)

    patch admin_file_upload_dry_run_path(dry_run)

    expect(response).to redirect_to(admin_file_upload_dry_run_path(dry_run))
    expect(flash[:notice]).to eq("単体ファイルアップロードを実行しました。")

    dry_run.reload
    expect(dry_run).to be_confirmed
    expect(dry_run.confirmed_by).to eq(admin_user)
    expect(dry_run.confirmed_at).to be_present
    expect(publish_job).to have_received(:update!).with(log_message: include("dry_run=#{dry_run.public_id}"))
  end

  it "rejects non-analyzed dry-runs" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run(status: :confirmed)

    allow(DocumentImporter).to receive(:new)

    patch admin_file_upload_dry_run_path(dry_run)

    expect(response).to redirect_to(admin_file_upload_dry_run_path(dry_run))
    expect(flash[:alert]).to eq("実行済み、または実行できないdry-runです。")
    expect(DocumentImporter).not_to have_received(:new)
  end

  it "rejects analyzed dry-runs that are missing artifact paths" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run(result_json: { "artifact_root" => "", "manifest_path" => "" })

    allow(DocumentImporter).to receive(:new)

    patch admin_file_upload_dry_run_path(dry_run)

    expect(response).to redirect_to(admin_file_upload_dry_run_path(dry_run))
    expect(flash[:alert]).to eq("file upload dry-run artifact is missing")
    expect(DocumentImporter).not_to have_received(:new)

    dry_run.reload
    expect(dry_run).to be_analyzed
    expect(dry_run.confirmed_by).to be_nil
    expect(dry_run.confirmed_at).to be_nil
  end

  it "does not expose ZIP dry-runs through the manual upload route" do
    sign_in_as(admin_user)
    dry_run = create_file_upload_dry_run(import_mode: :zip)

    get admin_file_upload_dry_run_path(dry_run)

    expect(response).to have_http_status(:not_found)
  end

  it "forbids company master admins and external users" do
    dry_run = create_file_upload_dry_run

    sign_in_as(create(:user, :company_master_admin))
    get admin_file_upload_dry_runs_path
    expect(response).to have_http_status(:forbidden)
    get admin_file_upload_dry_run_path(dry_run)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_file_upload_dry_runs_path
    expect(response).to have_http_status(:forbidden)
    get admin_file_upload_dry_run_path(dry_run)
    expect(response).to have_http_status(:forbidden)
  end

  private

  def create_file_upload_dry_run(import_mode: :manual_upload, status: :analyzed, project_override: nil, result_json: {}, warnings_json: [], errors_json: [])
    ImportDryRun.create!(
      import_mode:,
      status:,
      project: project_override || project,
      created_by: admin_user,
      source_commit_hash: "abc123sourcecommit",
      summary_json: { "total" => 1, "create_count" => 1, "update_count" => 0, "warning_count" => warnings_json.size },
      result_json: default_result_json.merge(result_json),
      warnings_json:,
      errors_json:
    )
  end

  def default_result_json
    {
      "artifact_root" => "/tmp/file-upload-artifact",
      "manifest_path" => "/tmp/file-upload-artifact/manifest.json",
      "items" => [
        {
          "source_path" => "docs/README.md",
          "title" => "README",
          "action" => "create"
        }
      ],
      "file_upload_preview" => {
        "source_name" => "local-folder-sync",
        "relative_path" => "docs/README.md",
        "source_path" => "C:/work/customer-docs/docs/README.md",
        "file_size" => 1234,
        "content_hash" => "abc123contenthash",
        "source_commit_hash" => "abc123sourcecommit",
        "version_label" => "file-v1",
        "zip_import_preview" => { "warnings" => [] }
      }
    }
  end
end
