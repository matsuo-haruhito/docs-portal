require "rails_helper"
require "fileutils"
require "tempfile"
require "zip"

RSpec.describe "Admin zip imports", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ZIPUI", name: "ZIP UI Project") }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:document_file_root) { Rails.root.join("storage", "document_files") }

  after do
    FileUtils.rm_rf(import_root.join("zip_uploads"))
    FileUtils.rm_rf(document_file_root.join("zip_uploads"))
  end

  it "shows the upload screen" do
    sign_in_as(admin_user)
    project

    get new_admin_zip_import_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIPインポート")
    expect(response.body).to include("dry-runで取り込み予定を確認してから実行")
    expect(response.body).to include("ZIPファイルをドラッグ")
    expect(response.body).to include("ZIPUI / ZIP UI Project")
  end

  it "creates a saved dry-run from an uploaded ZIP" do
    sign_in_as(admin_user)
    zip_file = build_uploaded_zip(
      "docs/README.md" => "# Imported from UI\n\n![Guide](assets/guide.png)\n",
      "docs/assets/guide.png" => "image"
    )

    expect do
      post admin_zip_imports_path, params: {
        project_id: project.id,
        zip_file: zip_file,
        version_label: "zip-ui-v1",
        status: "draft"
      }
    end.to change(ImportDryRun, :count).by(1)

    dry_run = ImportDryRun.last
    expect(response).to redirect_to(admin_zip_import_path(dry_run))
    expect(dry_run.zip?).to eq(true)
    expect(dry_run.project).to eq(project)
    expect(dry_run.result_json["artifact_root"]).to include("/storage/imports/zip_uploads/")
  ensure
    zip_file&.tempfile&.close!
  end

  it "rerenders the upload screen when the zip file is missing" do
    sign_in_as(admin_user)
    project

    expect do
      post admin_zip_imports_path, params: {
        project_id: project.id,
        version_label: "zip-ui-v1",
        status: "draft"
      }
    end.not_to change(ImportDryRun, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("ZIPインポート")
    expect(response.body).to include("ZIPUI / ZIP UI Project")
  end

  it "confirms an analyzed dry-run and dispatches the importer" do
    sign_in_as(admin_user)
    dry_run = create_zip_dry_run(
      result_json: {
        "artifact_root" => "/tmp/zip-import-artifact",
        "manifest_path" => "/tmp/zip-import-artifact/manifest.json"
      }
    )
    publish_job = double("publish_job", log_message: "started")
    allow(publish_job).to receive(:update!)
    importer = double("document_importer", call: publish_job)

    expect(DocumentImporter).to receive(:new).with(
      artifact_root: "/tmp/zip-import-artifact",
      manifest_path: "/tmp/zip-import-artifact/manifest.json",
      actor: admin_user
    ).and_return(importer)

    patch admin_zip_import_path(dry_run)

    expect(response).to redirect_to(admin_zip_import_path(dry_run))
    expect(flash[:notice]).to eq("ZIPインポートを実行しました。")

    dry_run.reload
    expect(dry_run).to be_confirmed
    expect(dry_run.confirmed_by).to eq(admin_user)
    expect(dry_run.confirmed_at).to be_present
    expect(publish_job).to have_received(:update!).with(log_message: include("dry_run=#{dry_run.public_id}"))
  end

  it "rejects analyzed dry-runs that are missing artifact paths" do
    sign_in_as(admin_user)
    dry_run = create_zip_dry_run(result_json: { "artifact_root" => "", "manifest_path" => "" })

    allow(DocumentImporter).to receive(:new)

    patch admin_zip_import_path(dry_run)

    expect(response).to redirect_to(admin_zip_import_path(dry_run))
    expect(flash[:alert]).to eq("ZIP dry-run artifact is missing")
    expect(DocumentImporter).not_to have_received(:new)

    dry_run.reload
    expect(dry_run).to be_analyzed
    expect(dry_run.confirmed_by).to be_nil
    expect(dry_run.confirmed_at).to be_nil
  end

  private

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["zip-import-admin", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { |stream| stream.write(content) }
      end
    end

    Rack::Test::UploadedFile.new(tempfile.path, "application/zip", original_filename: "sample.zip")
  end

  def create_zip_dry_run(result_json:, status: :analyzed)
    ImportDryRun.create!(
      import_mode: :zip,
      status:,
      project:,
      created_by: admin_user,
      summary_json: { "documents" => 1 },
      result_json: result_json,
      warnings_json: [],
      errors_json: []
    )
  end
end