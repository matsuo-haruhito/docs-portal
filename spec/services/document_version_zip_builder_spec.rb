require "rails_helper"
require "fileutils"

RSpec.describe DocumentVersionZipBuilder do
  let(:project) { create(:project, code: "ZIP") }
  let(:user) { create(:user, :internal, company: create(:company)) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:version) { create(:document_version, document:, version_label: "v1", source_relative_path: "docs/manual.md") }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "document-version-zip"))
  end

  def create_file_record(file_name:, content_type:, body:)
    storage_key = "spec/document-version-zip/#{SecureRandom.hex(8)}/#{file_name}"
    file = create(
      :document_file,
      document_version: version,
      file_name:,
      content_type:,
      storage_key:,
      file_size: body.bytesize,
      scan_status: :scan_clean
    )
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, body)
    file
  end

  it "builds archive entries for selected files and adds a readme" do
    create_file_record(file_name: "manual.md", content_type: "text/markdown", body: "# Manual")
    create_file_record(file_name: "manual.pdf", content_type: "application/pdf", body: "PDF")

    archive = described_class.new(version:, user:)

    expect(archive.filename).to eq("manual-v1.zip")
    expect(archive.entries.map(&:archive_path)).to include("manual.md", "manual.pdf", "README.txt")
    expect(archive).not_to be_empty
  end
end
