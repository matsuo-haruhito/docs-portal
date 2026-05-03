require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe DocumentFileHealthCheck do
  let(:version) { create(:document_version) }

  def create_document_file(file_name:, content: nil)
    storage_key = "spec/health-check/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)

    if content
      FileUtils.mkdir_p(absolute_path.dirname)
      File.binwrite(absolute_path, content)
    end

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type: "text/plain",
      storage_key:,
      file_size: content&.bytesize || 0
    )
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "health-check"))
  end

  it "counts total files and missing physical files" do
    existing = create_document_file(file_name: "existing.txt", content: "exists")
    missing = create_document_file(file_name: "missing.txt")

    result = described_class.new(DocumentFile.where(id: [existing.id, missing.id])).call

    expect(result.total_count).to eq(2)
    expect(result.missing_count).to eq(1)
    expect(result.missing_files).to eq([missing])
    expect(result).not_to be_healthy
  end

  it "limits missing file samples while keeping the full missing count" do
    missing_files = Array.new(3) { |index| create_document_file(file_name: "missing-#{index}.txt") }

    result = described_class.new(DocumentFile.where(id: missing_files.map(&:id))).call(limit: 2)

    expect(result.missing_count).to eq(3)
    expect(result.missing_files.size).to eq(2)
  end
end
