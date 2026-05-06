require "rails_helper"

RSpec.describe "Admin document archives", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ARCHIVE", name: "Archive Project") }
  let(:document) { create(:document, project:, title: "Old Manual", slug: "old-manual") }
  let!(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    allow_any_instance_of(ApplicationController).to receive(:admin_user?).and_return(true)
  end

  it "archives and restores a document from the admin screen" do
    sign_in_as(admin_user)

    patch archive_admin_document_path(document), params: {
      retention_until: "2026-12-31 00:00",
      discard_candidate_at: "2027-01-31 00:00"
    }

    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload.archived?).to eq(true)
    expect(document.archived_by_user).to eq(admin_user)
    expect(document.retention_until).to be_present
    expect(document.discard_candidate_at).to be_present

    patch restore_admin_document_path(document)

    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload.archived?).to eq(false)
  end
end
