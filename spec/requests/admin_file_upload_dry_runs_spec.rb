require "rails_helper"

RSpec.describe "Admin file upload dry runs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "FILEUI", name: "File UI Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
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
    expect(page_text).to include("同期元・path・hash 検索は表示中の safe metadata だけを対象にし、クライアント source path は検索対象に含めません。")

    get admin_file_upload_dry_runs_path, params: { q: "manual-upload/search" }
    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([path_match.public_id])

    get admin_file_upload_dry_runs_path, params: { q: "HASH-TARGET" }
    expect(response).to have_http_status(:ok)
    expect(listed_dry_run_ids).to eq([hash_match.public_id])

    get admin_file_upload_dry_runs_path, params: { q: "raw-source-only" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する単体ファイルアップロードdry-runはありません。")
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
