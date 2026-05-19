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
end
