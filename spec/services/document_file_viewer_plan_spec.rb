require "rails_helper"

RSpec.describe DocumentFileViewerPlan do
  let(:company) { create(:company) }
  let(:user) { create(:user, :internal, company:) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def plan_for(file)
    described_class.new(file:, user:).call
  end

  it "classifies mdx files as markdown preview" do
    file = create(:document_file, document_version: version, file_name: "guide.mdx", content_type: "application/octet-stream")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:markdown)
    expect(plan.label).to eq("Markdown preview")
    expect(plan).to be_previewable
    expect(plan).to be_inline_disposition
  end

  it "classifies pdf files as previewable pdf" do
    file = create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:pdf)
    expect(plan.label).to eq("PDF preview")
    expect(plan).to be_previewable
    expect(plan).to be_inline_disposition
  end

  it "classifies office files as office preview" do
    file = create(:document_file, document_version: version, file_name: "manual.docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:office)
    expect(plan.label).to eq("Office preview")
    expect(plan).to be_previewable
    expect(plan).to be_inline_disposition
  end

  it "classifies csv files as table preview" do
    file = create(:document_file, document_version: version, file_name: "items.csv", content_type: "text/plain")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:csv)
    expect(plan.label).to eq("Table preview")
    expect(plan).to be_previewable
  end

  it "classifies tsv extension files as previewable table preview" do
    file = create(:document_file, document_version: version, file_name: "items.tsv", content_type: "application/octet-stream")

    plan = plan_for(file)

    expect(file.effective_content_type).to eq("text/tab-separated-values; charset=utf-8")
    expect(plan.viewer_kind).to eq(:csv)
    expect(plan.label).to eq("Table preview")
    expect(plan).to be_previewable
    expect(plan).to be_inline_disposition
  end

  it "classifies tsv content type as table preview" do
    file = create(:document_file, document_version: version, file_name: "items.txt", content_type: "text/tab-separated-values")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:csv)
    expect(plan.label).to eq("Table preview")
    expect(plan).to be_previewable
  end

  it "classifies csv content type as table preview" do
    file = create(:document_file, document_version: version, file_name: "items.txt", content_type: "text/csv")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:csv)
    expect(plan.label).to eq("Table preview")
    expect(plan).to be_previewable
  end

  it "classifies zip archives as previewable zip preview" do
    file = create(:document_file, document_version: version, file_name: "bundle.zip", content_type: "application/zip")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:archive)
    expect(plan.label).to eq("ZIP preview")
    expect(plan).to be_previewable
    expect(plan).to be_inline_disposition
  end

  it "explains unsupported non-zip archive previews" do
    file = create(:document_file, document_version: version, file_name: "bundle.tar", content_type: "application/x-tar")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:archive)
    expect(plan.label).to eq("Archive")
    expect(plan).not_to be_previewable
    expect(plan.reason).to eq("ZIP以外の圧縮ファイル preview は未対応です")
  end

  it "falls back to download only for unknown binary files" do
    file = create(:document_file, document_version: version, file_name: "archive.bin", content_type: "application/octet-stream")

    plan = plan_for(file)

    expect(plan.viewer_kind).to eq(:download_only)
    expect(plan.label).to eq("Download only")
    expect(plan).not_to be_previewable
    expect(plan.reason).to eq("ブラウザ preview は未対応です")
  end

  it "blocks preview for external users until scan is clean" do
    external_user = create(:user, :external, company:)
    file = create(:document_file, :scan_pending, document_version: version, file_name: "manual.pdf", content_type: "application/pdf")

    plan = described_class.new(file:, user: external_user).call

    expect(plan.viewer_kind).to eq(:pdf)
    expect(plan).not_to be_previewable
    expect(plan.reason).to eq("ウイルススキャン完了後に表示できます")
  end
end