require "rails_helper"

RSpec.describe DocumentFileGoogleDrivePreview do
  it "builds a Google Drive file preview URL for Office files synced from Google Drive" do
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

    preview = described_class.new(file:)

    expect(preview).to be_available
    expect(preview.url).to eq("https://drive.google.com/file/d/drive-file-id/preview")
  end

  it "builds a Google Docs preview URL for exported Google native documents" do
    file = create(:document_file, file_name: "proposal.docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    source = create(:external_folder_sync_source, project: file.document_version.document.project)
    source.external_folder_sync_items.create!(
      document: file.document_version.document,
      document_version: file.document_version,
      document_file: file,
      external_item_id: "google-doc-id",
      path: "Folder/proposal.docx",
      name: "proposal.docx",
      mime_type: file.content_type,
      sync_status: :synced,
      provider_metadata: { source_mime_type: "application/vnd.google-apps.document" }
    )

    preview = described_class.new(file:)

    expect(preview).to be_available
    expect(preview.url).to eq("https://docs.google.com/document/d/google-doc-id/preview")
  end

  it "is unavailable for files that are not linked to Google Drive sync items" do
    file = create(:document_file, file_name: "sample.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    preview = described_class.new(file:)

    expect(preview).not_to be_available
    expect { preview.url }.to raise_error(DocumentFileGoogleDrivePreview::Error)
  end
end
