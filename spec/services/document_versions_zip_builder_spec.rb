require "rails_helper"
require "fileutils"

RSpec.describe DocumentVersionsZipBuilder do
  let(:project) { create(:project, code: "ZIP") }
  let(:user) { create(:user, :internal, company: create(:company)) }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "document-versions-zip"))
  end

  def create_file_record(version:, file_name:, body:)
    storage_key = "spec/document-versions-zip/#{SecureRandom.hex(8)}/#{file_name}"
    file = create(
      :document_file,
      document_version: version,
      file_name:,
      content_type: "application/pdf",
      storage_key:,
      file_size: body.bytesize,
      scan_status: :scan_clean
    )
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, body)
    file
  end

  it "names duplicate archive paths uniquely across versions" do
    first_document = create(:document, project:, title: "Doc A", slug: "doc-a")
    second_document = create(:document, project:, title: "Doc B", slug: "doc-b")
    first_version = create(:document_version, document: first_document, version_label: "v1")
    second_version = create(:document_version, document: second_document, version_label: "v1")

    create_file_record(version: first_version, file_name: "shared.pdf", body: "A")
    create_file_record(version: second_version, file_name: "shared.pdf", body: "B")

    archive = described_class.new(
      versions: [first_version, second_version],
      user:,
      zip_path_mode: :source_path
    )

    archive_paths = archive.entries.map(&:archive_path)
    pdf_paths = archive_paths.grep(/shared(?:-\d+)?\.pdf\z/)
    expect(pdf_paths.size).to eq(2)
    expect(pdf_paths.uniq.size).to eq(2)
    expect(archive_paths).to include("README.txt")
  end
end
