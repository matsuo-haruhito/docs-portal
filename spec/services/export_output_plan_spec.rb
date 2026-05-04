require "rails_helper"

RSpec.describe ExportOutputPlan do
  let(:company) { create(:company, name: "株式会社A") }
  let(:project) { create(:project, code: "EXPORT") }
  let(:viewer) { create(:user, :external, company:, email_address: "client@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:version) { create(:document_version, document:, source_relative_path: "docs/操作説明/manual.md") }

  it "builds zip paths and watermark text for export files" do
    file = create(:document_file, document_version: version, file_name: "操作説明.pdf")
    generated_at = Time.zone.local(2026, 5, 4, 12, 30, 0)

    result = described_class.new(
      project:,
      viewer:,
      files: [file],
      base_path: "deliverables",
      generated_at:
    ).call

    item = result.items.first
    expect(item.document).to eq(document)
    expect(item.document_version).to eq(version)
    expect(item.document_file).to eq(file)
    expect(item.output_file_name).to eq("操作説明.pdf")
    expect(item.zip_path).to eq("deliverables/docs/操作説明/操作説明.pdf")
    expect(item.watermark_text).to eq("Confidential - 株式会社A - client@example.com - EXPORT - #{document.public_id} - 2026-05-04 12:30")
    expect(result.zip_paths).to eq(["deliverables/docs/操作説明/操作説明.pdf"])
    expect(result.output_file_names).to eq(["操作説明.pdf"])
  end

  it "sanitizes path separators in output file names" do
    file = create(:document_file, document_version: version, file_name: "folder\\unsafe/name.pdf")

    item = described_class.new(project:, viewer:, files: [file]).call.items.first

    expect(item.output_file_name).to eq("folder_unsafe_name.pdf")
    expect(item.zip_path).to eq("docs/操作説明/folder_unsafe_name.pdf")
  end

  it "can omit source paths and watermark text" do
    file = create(:document_file, document_version: version, file_name: "manual.pdf")

    item = described_class.new(
      project:,
      viewer:,
      files: [file],
      include_source_path: false,
      watermark: false
    ).call.items.first

    expect(item.zip_path).to eq("manual.pdf")
    expect(item.watermark_text).to be_nil
  end
end
