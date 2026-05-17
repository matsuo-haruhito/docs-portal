require "rails_helper"

RSpec.describe DocumentFileArchivePreview do
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

  def write_storage_file(storage_key, content)
    File.binwrite(storage_path(storage_key), content)
  end

  it "lists zip entries" do
    storage_key = "spec/archive-preview/items.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "image.png" => "png"
    })
    file = create(:document_file, document_version: version, file_name: "items.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview).not_to be_error
    expect(preview).not_to be_truncated
    expect(preview.entries.map(&:name)).to include("docs/readme.txt", "image.png")
    readme = preview.entries.find { _1.name == "docs/readme.txt" }
    expect(readme).not_to be_directory
    expect(readme.size).to eq(5)
  end

  it "exposes entry parent directories" do
    storage_key = "spec/archive-preview/parent-directory.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "index.html" => "html"
    })
    file = create(:document_file, document_version: version, file_name: "parent-directory.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    parents = preview.entries.index_by(&:name).transform_values(&:parent_directory)
    expect(parents["docs/"]).to eq("/")
    expect(parents["docs/readme.txt"]).to eq("docs/")
    expect(parents["index.html"]).to eq("/")
  end

  it "summarizes zip entries" do
    storage_key = "spec/archive-preview/summary.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "image.png" => "png"
    })
    file = create(:document_file, document_version: version, file_name: "summary.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.file_entries.map(&:name)).to contain_exactly("docs/readme.txt", "image.png")
    expect(preview.file_count).to eq(2)
    expect(preview.folder_count).to eq(1)
    expect(preview.total_file_size).to eq(8)
  end

  it "summarizes entries by directory" do
    storage_key = "spec/archive-preview/directory-summary.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "docs/images/" => :directory,
      "docs/images/logo.png" => "png",
      "index.html" => "html"
    })
    file = create(:document_file, document_version: version, file_name: "directory-summary.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    summaries = preview.directory_summaries.index_by(&:path)
    expect(summaries.keys).to contain_exactly("/", "docs/", "docs/images/")
    expect(summaries["/"].file_count).to eq(1)
    expect(summaries["/"].folder_count).to eq(1)
    expect(summaries["/"].total_file_size).to eq(4)
    expect(summaries["docs/"].file_count).to eq(1)
    expect(summaries["docs/"].folder_count).to eq(1)
    expect(summaries["docs/"].total_file_size).to eq(5)
    expect(summaries["docs/images/"].file_count).to eq(1)
    expect(summaries["docs/images/"].folder_count).to eq(0)
    expect(summaries["docs/images/"].total_file_size).to eq(3)
  end

  it "truncates entries over the limit" do
    storage_key = "spec/archive-preview/large.zip"
    write_zip(storage_key, {
      "one.txt" => "1",
      "two.txt" => "2",
      "three.txt" => "3"
    })
    file = create(:document_file, document_version: version, file_name: "large.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:, limit: 2).call

    expect(preview.entries.size).to eq(2)
    expect(preview).to be_truncated
    expect(preview.limit).to eq(2)
  end

  it "returns an error result for broken zip" do
    storage_key = "spec/archive-preview/broken.zip"
    write_storage_file(storage_key, "not a zip")
    file = create(:document_file, document_version: version, file_name: "broken.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.entries).to eq([])
    expect(preview).to be_error
    expect(preview.error).to be_present
  end

  it "returns an error result for unsupported archive format" do
    storage_key = "spec/archive-preview/items.tar"
    write_storage_file(storage_key, "tar")
    file = create(:document_file, document_version: version, file_name: "items.tar", content_type: "application/x-tar", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.entries).to eq([])
    expect(preview).to be_error
    expect(preview.error).to include("未対応")
  end
end
