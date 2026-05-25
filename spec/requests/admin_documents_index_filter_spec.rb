require "rails_helper"

RSpec.describe "Admin documents index filters", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "filters documents by keyword and enum params" do
    target_project = create(:project, code: "ALPHA", name: "Alpha Project")
    other_project = create(:project, code: "BETA", name: "Beta Project")
    matching_document = create(
      :document,
      project: target_project,
      title: "Operations Handbook",
      slug: "operations-handbook",
      category: :manual,
      document_kind: :word,
      visibility_policy: :public_with_login
    )
    create(
      :document,
      project: other_project,
      title: "Meeting Note",
      slug: "meeting-note",
      category: :meeting_note,
      document_kind: :markdown,
      visibility_policy: :internal_only
    )

    sign_in_as(admin_user)

    get admin_documents_path, params: {
      q: "ALPHA",
      category: "manual",
      document_kind: "word",
      visibility_policy: "public_with_login"
    }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(response.body).to include("検索・絞り込み")
      expect(response.body).to include(matching_document.title)
      expect(response.body).not_to include("Meeting Note")
    end
  end

  it "filters archived documents by due retention and discard state" do
    create(:document, title: "Active Document")

    due_document = create(:document, title: "Due Document")
    due_document.update!(
      archived_at: 3.days.ago,
      archived_by_user: admin_user,
      retention_until: 2.days.ago,
      discard_candidate_at: 1.day.ago
    )

    future_document = create(:document, title: "Future Document")
    future_document.update!(
      archived_at: 3.days.ago,
      archived_by_user: admin_user,
      retention_until: 2.days.from_now,
      discard_candidate_at: 3.days.from_now
    )

    sign_in_as(admin_user)

    get admin_documents_path, params: {
      archived: "archived",
      retention: "due",
      discard: "due"
    }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(response.body).to include(due_document.title)
      expect(response.body).not_to include("Active Document")
      expect(response.body).not_to include(future_document.title)
    end
  end
end
