require "rails_helper"

RSpec.describe "Document version preview build status", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "VERPREVIEW", name: "Version Preview Project") }
  let(:document) { create(:document, project:, title: "Preview Guide", slug: "preview-guide") }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :draft,
      source_commit_hash: "manual-upload"
    ).tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/preview-guide.md", snapshot_kind: "received_markdown")
      record.save!
      record.mark_preview_build_queued!
    end
  end

  before do
    document.update!(latest_version: version)
  end

  it "exposes the persistent preview state on the version detail card" do
    sign_in_as(user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    status_card = document.at_css('[data-preview-build-status="preview_queued"]')
    expect(status_card).to be_present
    expect(status_card.css("ul.compact-list li")).not_to be_empty
  end
end
