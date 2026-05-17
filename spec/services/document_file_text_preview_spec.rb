require "rails_helper"

RSpec.describe DocumentFileTextPreview do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def write_storage_file(storage_key, content, mode: "w")
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    File.open(path, mode) { |file| file.write(content) }
  end

  it "reads text lines" do
    storage_key = "spec/text-preview/notes.txt"
    write_storage_file(storage_key, "one\ntwo\nthree\n")
    file = create(:document_file, document_version: version, file_name: "notes.txt", content_type: "text/plain", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.lines).to eq(%w[one two three])
    expect(preview).not_to be_truncated
    expect(preview).not_to be_error
  end

  it "preserves blank lines" do
    storage_key = "spec/text-preview/blank-lines.txt"
    write_storage_file(storage_key, "one\n\nthree\n")
    file = create(:document_file, document_version: version, file_name: "blank-lines.txt", content_type: "text/plain", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.lines).to eq(["one", "", "three"])
  end

  it "truncates lines over the limit" do
    storage_key = "spec/text-preview/large.txt"
    write_storage_file(storage_key, "one\ntwo\nthree\n")
    file = create(:document_file, document_version: version, file_name: "large.txt", content_type: "text/plain", storage_key:)

    preview = described_class.new(file:, limit: 2).call

    expect(preview.lines).to eq(%w[one two])
    expect(preview).to be_truncated
    expect(preview.limit).to eq(2)
  end

  it "returns an error result for invalid utf-8" do
    storage_key = "spec/text-preview/invalid.txt"
    write_storage_file(storage_key, "\xFF".b, mode: "wb")
    file = create(:document_file, document_version: version, file_name: "invalid.txt", content_type: "text/plain", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.lines).to eq([])
    expect(preview).to be_error
    expect(preview.error).to be_present
  end
end
