require "rails_helper"

RSpec.describe DocumentFileArchiveEntryDownload do
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
    storage_key = "spec/archive-entry-download/items.zip"
    write_zip(storage_key, entries)
    create(:document_file, document_version: version, file_name: "items.zip", content_type: "application/zip", storage_key:)
  end

  def download(file, entry_path, **options)
    described_class.new(file:, entry_path:, **options).call
  end

  it "reads a downloadable text entry as binary data" do
    file = build_zip("docs/readme.txt" => "hello")

    result = download(file, "docs/readme.txt")

    expect(result).to be_downloadable
    expect(result).not_to be_error
    expect(result.entry_path).to eq("docs/readme.txt")
    expect(result.filename).to eq("readme.txt")
    expect(result.content_type).to eq("text/plain")
    expect(result.size).to eq(5)
    expect(result.data).to eq("hello")
  end

  it "reads a binary entry as binary data" do
    file = build_zip("images/logo.png" => "\x89PNG".b)

    result = download(file, "images/logo.png")

    expect(result).to be_downloadable
    expect(result).not_to be_error
    expect(result.filename).to eq("logo.png")
    expect(result.data).to eq("\x89PNG".b)
  end

  it "returns lookup reason for unsafe paths" do
    file = build_zip("docs/readme.txt" => "hello")

    result = download(file, "../secret.txt")

    expect(result).not_to be_downloadable
    expect(result).to be_error
    expect(result.data).to be_nil
    expect(result.reason).to eq("unsafe path のため操作できません")
  end

  it "returns lookup reason for directories" do
    file = build_zip("docs/" => :directory)

    result = download(file, "docs/")

    expect(result).not_to be_downloadable
    expect(result).to be_error
    expect(result.data).to be_nil
    expect(result.reason).to eq("directory entry は操作対象外です")
  end

  it "returns lookup reason for entries over the size limit" do
    file = build_zip("docs/large.txt" => "hello")
    lookup = DocumentFileArchiveEntryLookup.new(file:, entry_path: "docs/large.txt", max_size: 4).call

    result = described_class.new(file:, entry_path: "docs/large.txt", lookup:).call

    expect(result).not_to be_downloadable
    expect(result).to be_error
    expect(result.data).to be_nil
    expect(result.reason).to eq("entry size が上限を超えています")
  end

  it "blocks nested archive entries" do
    file = build_zip("nested/archive.zip" => "zip")

    result = download(file, "nested/archive.zip")

    expect(result).not_to be_downloadable
    expect(result).to be_error
    expect(result.data).to be_nil
    expect(result.reason).to eq("nested archive entry はdownload対象外です")
  end

  it "uses a provided lookup result" do
    file = build_zip("docs/readme.txt" => "hello")
    lookup = DocumentFileArchiveEntryLookup.new(file:, entry_path: "docs/readme.txt").call

    result = described_class.new(file:, entry_path: "ignored.txt", lookup:).call

    expect(result).to be_downloadable
    expect(result.entry_path).to eq("docs/readme.txt")
    expect(result.data).to eq("hello")
  end
end
