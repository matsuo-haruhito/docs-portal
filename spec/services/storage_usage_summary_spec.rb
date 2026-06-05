require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe StorageUsageSummary do
  let(:storage_root) { Rails.root.join("tmp", "storage-usage-summary", SecureRandom.hex(8)) }

  after do
    FileUtils.rm_rf(storage_root)
  end

  def write_storage_file(relative_path, content)
    path = storage_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, content)
  end

  it "summarizes local storage usage by supported operational area" do
    write_storage_file("document_files/project-a/manual.pdf", "document")
    write_storage_file("docs_sites/123/index.html", "site")
    write_storage_file("imports/dry-run/manifest.json", "{}")
    write_storage_file("imports/dry-run/files/source.md", "markdown")

    result = described_class.new(storage_root:).call

    expect(result.total_file_count).to eq(4)
    expect(result.total_bytes).to eq("documentsite{}markdown".bytesize)
    expect(result.areas.map(&:key)).to eq(%i[document_files docs_sites imports])

    document_files_area = result.areas.find { |area| area.key == :document_files }
    docs_sites_area = result.areas.find { |area| area.key == :docs_sites }
    imports_area = result.areas.find { |area| area.key == :imports }

    expect(document_files_area.relative_path).to eq("storage/document_files")
    expect(document_files_area.file_count).to eq(1)
    expect(document_files_area.bytes).to eq("document".bytesize)
    expect(docs_sites_area.file_count).to eq(1)
    expect(docs_sites_area.bytes).to eq("site".bytesize)
    expect(imports_area.file_count).to eq(2)
    expect(imports_area.bytes).to eq("{}markdown".bytesize)
  end

  it "returns zero usage for missing storage directories" do
    result = described_class.new(storage_root:).call

    expect(result.total_file_count).to eq(0)
    expect(result.total_bytes).to eq(0)
    expect(result.areas).to all(have_attributes(file_count: 0, bytes: 0))
  end
end
