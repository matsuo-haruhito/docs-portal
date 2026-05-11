require "rails_helper"

RSpec.describe DocumentFileOfficePreview do
  it "uses Google Drive preview when Microsoft Graph is not configured" do
    file = create(:document_file, file_name: "sample.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    source = create(:external_folder_sync_source, project: file.document_version.document.project)
    source.external_folder_sync_items.create!(
      document: file.document_version.document,
      document_version: file.document_version,
      document_file: file,
      external_item_id: "drive-file-id",
      path: "Folder/sample.xlsx",
      name: "sample.xlsx",
      mime_type: file.content_type,
      sync_status: :synced,
      provider_metadata: { source_mime_type: file.content_type }
    )

    preview = described_class.new(file:, user: create(:user, :internal))

    expect(preview).to be_available
    expect(preview.url).to eq("https://drive.google.com/file/d/drive-file-id/preview")
  end

  it "is unavailable when neither Microsoft Graph nor Google Drive preview can be used" do
    file = create(:document_file, file_name: "sample.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    preview = described_class.new(file:, user: create(:user, :internal))

    expect(preview).not_to be_available
    expect { preview.url }.to raise_error(DocumentFileOfficePreview::Error)
  end
end
