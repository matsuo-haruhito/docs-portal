require "rails_helper"

RSpec.describe DocumentFileCsvPreview do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def write_storage_file(storage_key, content)
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  it "parses csv rows" do
    storage_key = "spec/csv-preview/items.csv"
    write_storage_file(storage_key, "name,count\napple,3\norange,5\n")
    file = create(:document_file, document_version: version, file_name: "items.csv", content_type: "text/csv", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.rows).to eq([
      %w[name count],
      %w[apple 3],
      %w[orange 5]
    ])
    expect(preview).not_to be_truncated
    expect(preview).not_to be_error
  end

  it "parses tsv rows" do
    storage_key = "spec/csv-preview/items.tsv"
    write_storage_file(storage_key, "name\tcount\napple\t3\n")
    file = create(:document_file, document_version: version, file_name: "items.tsv", content_type: "text/tab-separated-values", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.rows).to eq([
      %w[name count],
      %w[apple 3]
    ])
  end

  it "truncates rows over the limit" do
    storage_key = "spec/csv-preview/large.csv"
    write_storage_file(storage_key, "a\n1\n2\n3\n")
    file = create(:document_file, document_version: version, file_name: "large.csv", content_type: "text/csv", storage_key:)

    preview = described_class.new(file:, limit: 2).call

    expect(preview.rows).to eq([["a"], ["1"]])
    expect(preview).to be_truncated
    expect(preview.limit).to eq(2)
  end

  it "returns an error result for malformed csv" do
    storage_key = "spec/csv-preview/broken.csv"
    write_storage_file(storage_key, "name,count\n\"apple,3\n")
    file = create(:document_file, document_version: version, file_name: "broken.csv", content_type: "text/csv", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.rows).to eq([])
    expect(preview).to be_error
    expect(preview.error).to be_present
  end
end
