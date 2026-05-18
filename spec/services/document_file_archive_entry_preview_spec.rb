require "rails_helper"

RSpec.describe DocumentFileArchiveEntryPreview do
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
    storage_key = "spec/archive-entry-preview/items.zip"
    write_zip(storage_key, entries)
    create(:document_file, document_version: version, file_name: "items.zip", content_type: "application/zip", storage_key:)
  end

  def preview(file, entry_path, **options)
    described_class.new(file:, entry_path:, **options).call
  end

  it "reads a text entry" do
    file = build_zip("docs/readme.txt" => "one\ntwo\n")

    result = preview(file, "docs/readme.txt")

    expect(result).to be_previewable
    expect(result).not_to be_error
    expect(result).not_to be_truncated
    expect(result.entry_path).to eq("docs/readme.txt")
    expect(result.filename).to eq("readme.txt")
    expect(result.content_type).to eq("text/plain")
    expect(result.text).to eq("one\ntwo\n")
    expect(result.lines).to eq(%w[one two])
    expect(result.line_count).to eq(2)
  end

  it "returns lookup reason for non-previewable entries" do
    file = build_zip("images/logo.png" => "png")

    result = preview(file, "images/logo.png")

    expect(result).not_to be_previewable
    expect(result).to be_error
    expect(result.lines).to eq([])
    expect(result.text).to be_nil
    expect(result.reason).to eq("text preview 対象外です")
  end

  it "returns lookup reason for unsafe paths" do
    file = build_zip("docs/readme.txt" => "hello")

    result = preview(file, "../secret.txt")

    expect(result).not_to be_previewable
    expect(result).to be_error
    expect(result.reason).to eq("unsafe path のため操作できません")
  end

  it "truncates lines over the line limit" do
    file = build_zip("docs/large.txt" => "one\ntwo\nthree\n")

    result = preview(file, "docs/large.txt", line_limit: 2)

    expect(result).to be_previewable
    expect(result).to be_truncated
    expect(result.lines).to eq(%w[one two])
    expect(result.line_limit).to eq(2)
  end

  it "returns an error for invalid UTF-8" do
    file = build_zip("docs/binary.txt" => "\xFF".b)

    result = preview(file, "docs/binary.txt")

    expect(result).not_to be_previewable
    expect(result).to be_error
    expect(result.lines).to eq([])
    expect(result.reason).to be_present
  end

  it "uses a provided lookup result" do
    file = build_zip("docs/readme.txt" => "hello")
    lookup = DocumentFileArchiveEntryLookup.new(file:, entry_path: "docs/readme.txt").call

    result = described_class.new(file:, entry_path: "ignored.txt", lookup:).call

    expect(result).to be_previewable
    expect(result.entry_path).to eq("docs/readme.txt")
    expect(result.lines).to eq(["hello"])
  end
end
