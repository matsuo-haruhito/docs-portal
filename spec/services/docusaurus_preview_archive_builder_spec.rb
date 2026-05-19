require "rails_helper"
require "rubygems/package"
require "zlib"

RSpec.describe DocusaurusPreviewArchiveBuilder do
  let(:document) { create(:document, title: "Guide", slug: "guide") }
  let(:version) do
    create(:document_version, document: document, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
      record.save!
    end
  end

  after do
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/docusaurus-preview-archive-builder"))
  end

  it "packs version document files using their safe document paths" do
    create_document_file!("docs/guide.md", "# Guide")
    create_document_file!("docs/assets/image.txt", "image")

    archive = described_class.new(version).build

    expect(read_archive(archive.path)).to include(
      "docs/guide.md" => "# Guide",
      "docs/assets/image.txt" => "image"
    )
  ensure
    archive&.close!
  end

  it "rejects unsafe document file paths" do
    create_document_file!("../escape.md", "escape")

    expect do
      archive = described_class.new(version).build
    end.to raise_error(ApplicationError::BadRequest, /invalid/)
  ensure
    archive&.close! if defined?(archive) && archive
  end

  private

  def create_document_file!(file_name, content)
    storage_key = "spec/docusaurus-preview-archive-builder/#{SecureRandom.hex(8)}.md"
    absolute_path = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    absolute_path.write(content)

    version.document_files.create!(
      file_name: file_name,
      content_type: "text/markdown",
      storage_key: storage_key,
      file_size: absolute_path.size,
      sort_order: version.document_files.count,
      scan_status: :scan_pending
    )
  end

  def read_archive(path)
    result = {}
    Zlib::GzipReader.open(path) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          result[entry.full_name] = entry.read if entry.file?
        end
      end
    end
    result
  end
end
