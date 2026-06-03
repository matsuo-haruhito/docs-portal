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

  def heading_texts
    parsed_html.css("h1, h2, h3").map { _1.text.squish }.reject(&:empty?)
  end

  def submit_button_texts(action)
    parsed_html.css(%(form[action="#{action}"] button, form[action="#{action}"] input[type="submit"])).map do |node|
      node["value"].presence || node.text.squish
    end
  end

  it "shows a manual upload dry-run with file metadata and preview" do
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
    expect(page_text).to include("README.md（フルパスは非表示）")
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
    get admin_file_upload_dry_run_path(dry_run)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_file_upload_dry_run_path(dry_run)
    expect(response).to have_http_status(:forbidden)
  end

  private

  def create_file_upload_dry_run(import_mode: :manual_upload, status: :analyzed, result_json: {}, warnings_json: [], errors_json: [])
    ImportDryRun.create!(
      import_mode:,
      status:,
      project:,
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