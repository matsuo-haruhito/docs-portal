require "rails_helper"

RSpec.describe PublicIdentifiable, type: :model do
  it "auto-generates public_id for access logs on create" do
    log = AccessLog.create!(
      action_type: :view,
      target_type: "page",
      target_name: "index.html",
      accessed_at: Time.current
    )

    expect(log.public_id).to be_present
    expect(log.public_id).to start_with("alog_")
  end

  it "auto-generates public_id for representative application models on create" do
    project = create(:project)
    document = create(:document, project:)
    version = create(:document_version, document:)
    file = DocumentFile.create!(
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/manual.pdf",
      file_size: 1
    )

    expect(project.public_id).to start_with("prj_")
    expect(document.public_id).to start_with("doc_")
    expect(version.public_id).to start_with("ver_")
    expect(file.public_id).to start_with("file_")
  end
end
