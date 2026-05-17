require "rails_helper"

RSpec.describe DocumentFileArchiveEntryLookup do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def storage_path(storage_key)
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    path
  end

  def write_zip(storage_key, entries)
    Zip::File.open(storage_path(storage_key), create: true) do |zip_file|
      entries.each do |name, content|
        if content == :directory
          zip_file.mkdir(name)
        else
          zip_file.get_output_stream(name) { |io| io.write(content) }
        end
      end
    end
  end

  def build_zip(entries)
    storage_key = "spec/archive-entry-lookup/items.zip"
    write_zip(storage_key, entries)
    create(:document_file, document_version: version, file_name: "items.zip", content_type: "application/zip", storage_key:)
  end

  def lookup(file, entry_path, max_size: described_class::DEFAULT_MAX_SIZE)
    described_class.new(file:, entry_path:, max_size:).call
  end

  it "returns metadata for a text preview candidate" do
    file = build_zip("docs/readme.txt" => "hello")

    result = lookup(file, "docs/readme.txt")

    expect(result).to be_found
    expect(result).to be_safe_path
    expect(result).not_to be_directory
    expect(result).to be_previewable
    expect(result).to be_downloadable
    expect(result.entry_path).to eq("docs/readme.txt")
    expect(result.filename).to eq("readme.txt")
    expect(result.content_type).to eq("text/plain")
    expect(result.size).to eq(5)
    expect(result.reason).to be_nil
  end

  it "normalizes a leading slash before lookup" do
    file = build_zip("docs/readme.txt" => "hello")

    result = lookup(file, "/docs/readme.txt")

    expect(result).to be_found
    expect(result.entry_path).to eq("docs/readme.txt")
  end

  it "rejects unsafe paths" do
    file = build_zip("docs/readme.txt" => "hello")

    result = lookup(file, "../secret.txt")

    expect(result).not_to be_found
    expect(result).not_to be_safe_path
    expect(result).not_to be_previewable
    expect(result).not_to be_downloadable
    expect(result.reason).to eq("unsafe path のため操作できません")
  end

  it "returns a missing result" do
    file = build_zip("docs/readme.txt" => "hello")

    result = lookup(file, "missing.txt")

    expect(result).not_to be_found
    expect(result).to be_safe_path
    expect(result.reason).to eq("entry が見つかりません")
  end

  it "returns a directory result" do
    file = build_zip("docs/" => :directory)

    result = lookup(file, "docs/")

    expect(result).to be_found
    expect(result).to be_directory
    expect(result).not_to be_previewable
    expect(result).not_to be_downloadable
    expect(result.reason).to eq("directory entry は操作対象外です")
  end

  it "marks binary files as download-only candidates" do
    file = build_zip("images/logo.png" => "png")

    result = lookup(file, "images/logo.png")

    expect(result).to be_found
    expect(result).not_to be_previewable
    expect(result).to be_downloadable
    expect(result.reason).to eq("text preview 対象外です")
  end

  it "rejects entries over the size limit" do
    file = build_zip("docs/large.txt" => "hello")

    result = lookup(file, "docs/large.txt", max_size: 4)

    expect(result).to be_found
    expect(result).not_to be_previewable
    expect(result).not_to be_downloadable
    expect(result.reason).to eq("entry size が上限を超えています")
  end
end
