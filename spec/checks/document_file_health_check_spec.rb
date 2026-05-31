require "rails_helper"

RSpec.describe DocumentFileHealthCheck do
  let(:version) { create(:document_version) }

  def create_document_file(index)
    create(
      :document_file,
      document_version: version,
      file_name: "health-check-#{index}.txt",
      storage_key: "spec/document-file-health-check/health-check-#{index}.txt"
    )
  end

  it "counts all files while keeping missing file details within the configured limit" do
    files = Array.new(3) { |index| create_document_file(index) }

    result = described_class.new(DocumentFile.where(id: files.map(&:id))).call(limit: 2)

    expect(result.total_count).to eq(3)
    expect(result.missing_count).to eq(3)
    expect(result.missing_files).to match_array(files.first(2))
    expect(result).not_to be_healthy
  end

  it "reports healthy when every registered file exists" do
    file = create_document_file("existing")

    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:file?).with(file.absolute_path).and_return(true)

    result = described_class.new(DocumentFile.where(id: file.id)).call

    expect(result.total_count).to eq(1)
    expect(result.missing_count).to eq(0)
    expect(result.missing_files).to be_empty
    expect(result).to be_healthy
  end
end
