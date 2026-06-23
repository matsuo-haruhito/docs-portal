require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe StorageUsageSummary do
  let(:storage_root) { Rails.root.join("tmp", "storage-usage-summary", SecureRandom.hex(8)) }
  let(:storage_key_prefix) { "spec/storage-usage-summary/#{SecureRandom.hex(4)}" }

  after do
    FileUtils.rm_rf(storage_root)
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/storage-usage-summary"))
  end

  def write_storage_file(relative_path, content)
    path = storage_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, content)
  end

  def create_document_file_with_content(document_version:, storage_key:, content: nil, file_name: File.basename(storage_key))
    file = create(
      :document_file,
      document_version:,
      file_name:,
      storage_key:,
      file_size: content.to_s.bytesize
    )

    if content
      path = file.absolute_path
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content)
    end

    file
  end

  it "summarizes local storage usage by supported operational area" do
    write_storage_file("document_files/project-a/manual.pdf", "document")
    write_storage_file("docs_sites/123/index.html", "site")
    write_storage_file("imports/dry-run/manifest.json", "{}")
    write_storage_file("imports/dry-run/files/source.md", "markdown")
    write_storage_file("tmp/cache.bin", "ignored")

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
    expect(document_files_area.breakdown_entries.map(&:relative_path)).to eq(["storage/document_files/project-a"])
    expect(docs_sites_area.file_count).to eq(1)
    expect(docs_sites_area.bytes).to eq("site".bytesize)
    expect(docs_sites_area.breakdown_entries.map(&:relative_path)).to eq(["storage/docs_sites/123"])
    expect(docs_sites_area.breakdown_entries.first.latest_updated_at).to be_present
    expect(imports_area.file_count).to eq(2)
    expect(imports_area.bytes).to eq("{}markdown".bytesize)
    expect(imports_area.breakdown_entries.map(&:relative_path)).to eq(["storage/imports/dry-run"])
    expect(imports_area.breakdown_entries.first.latest_updated_at).to be_present
  end

  it "returns zero usage for missing storage directories and ignores empty directories" do
    FileUtils.mkdir_p(storage_root.join("document_files/empty/nested"))

    result = described_class.new(storage_root:).call

    expect(result.total_file_count).to eq(0)
    expect(result.total_bytes).to eq(0)
    expect(result.areas).to all(have_attributes(file_count: 0, bytes: 0, breakdown_entries: []))
  end

  it "returns top five direct children by bytes without exposing absolute paths" do
    {
      "alpha" => 10,
      "beta" => 60,
      "gamma" => 30,
      "delta" => 50,
      "epsilon" => 40,
      "zeta" => 20
    }.each do |child, bytes|
      write_storage_file("document_files/#{child}/artifact.bin", "x" * bytes)
    end
    write_storage_file("document_files/beta/second.bin", "yy")
    write_storage_file("document_files/root-note.txt", "root")

    result = described_class.new(storage_root:).call
    document_files_area = result.areas.find { |area| area.key == :document_files }

    expect(document_files_area.file_count).to eq(8)
    expect(document_files_area.breakdown_entries.map(&:relative_path)).to eq([
      "storage/document_files/beta",
      "storage/document_files/delta",
      "storage/document_files/epsilon",
      "storage/document_files/gamma",
      "storage/document_files/zeta"
    ])
    expect(document_files_area.breakdown_entries.map(&:bytes)).to eq([62, 50, 40, 30, 20])
    expect(document_files_area.breakdown_entries.first.file_count).to eq(2)
    expect(document_files_area.breakdown_entries.first.latest_updated_at).to be_present
    expect(document_files_area.breakdown_entries.map(&:relative_path).join).not_to include(storage_root.to_s)
  end

  it "skips vanished files while keeping the area summary available" do
    volatile_path = storage_root.join("imports", "volatile", "payload.json")
    write_storage_file("imports/volatile/payload.json", "payload")

    allow(File).to receive(:size).and_call_original
    allow(File).to receive(:size).with(volatile_path.to_s).and_raise(Errno::ENOENT)

    result = described_class.new(storage_root:).call
    imports_area = result.areas.find { |area| area.key == :imports }

    expect(imports_area.file_count).to eq(0)
    expect(imports_area.bytes).to eq(0)
    expect(imports_area.breakdown_entries).to eq([])
  end

  it "groups DocumentFile storage by Project and Document without exposing raw paths" do
    project = create(:project, code: "STOR3248", name: "Storage Owner")
    document = create(:document, project:, title: "Storage Heavy", slug: "storage-heavy")
    version = create(:document_version, document:)
    other_document = create(:document, project:, title: "Storage Light", slug: "storage-light")
    other_version = create(:document_version, document: other_document)

    create_document_file_with_content(
      document_version: version,
      storage_key: "#{storage_key_prefix}/heavy/one.bin",
      content: "a" * 300
    )
    create_document_file_with_content(
      document_version: version,
      storage_key: "#{storage_key_prefix}/heavy/two.bin",
      content: "b" * 200
    )
    create_document_file_with_content(
      document_version: version,
      storage_key: "#{storage_key_prefix}/heavy/missing.bin",
      content: nil
    )
    create_document_file_with_content(
      document_version: other_version,
      storage_key: "#{storage_key_prefix}/light/one.bin",
      content: "c" * 50
    )

    entries = described_class.new.call.document_file_breakdown_entries
    heavy_entry = entries.find { _1.project_code == "STOR3248" && _1.document_slug == "storage-heavy" }
    light_entry = entries.find { _1.document_slug == "storage-light" }

    expect(heavy_entry).to be_present
    expect(heavy_entry.project_name).to eq("Storage Owner")
    expect(heavy_entry.document_title).to eq("Storage Heavy")
    expect(heavy_entry.bytes).to eq(500)
    expect(heavy_entry.file_count).to eq(3)
    expect(heavy_entry.missing_file_count).to eq(1)
    expect(heavy_entry.human_size).to eq("500 Bytes")
    expect(heavy_entry.latest_updated_at).to be_present
    expect(light_entry.bytes).to eq(50)
    expect(entries.map(&:document_slug).join).not_to include(DocumentFile.storage_root.to_s)
  end

  it "limits the DocumentFile breakdown to the largest dashboard entries" do
    project = create(:project, code: "LIMIT3248")

    6.times do |index|
      document = create(:document, project:, title: "Storage Rank #{index}", slug: "storage-rank-#{index}")
      version = create(:document_version, document:)
      create_document_file_with_content(
        document_version: version,
        storage_key: "#{storage_key_prefix}/rank-#{index}/file.bin",
        content: "x" * (index + 1)
      )
    end

    entries = described_class.new.call.document_file_breakdown_entries

    expect(entries.size).to eq(StorageUsageSummary::TOP_BREAKDOWN_LIMIT)
    expect(entries.map(&:document_slug)).to include("storage-rank-5")
    expect(entries.map(&:document_slug)).not_to include("storage-rank-0")
  end
end
