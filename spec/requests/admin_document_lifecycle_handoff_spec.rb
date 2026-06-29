require "rails_helper"

RSpec.describe "Admin document lifecycle handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def json_response
    JSON.parse(response.body)
  end

  def document_lifecycle_snapshot
    Document.order(:id).map do |document|
      [document.id, document.archived?, document.retention_until, document.discard_candidate_at]
    end
  end

  it "returns read-only handoff candidates for the current lifecycle filter" do
    project = create(:project, code: "LIFE", name: "Lifecycle Project")
    active_due_document = create(:document,
      project:,
      title: "Lifecycle Active Due",
      slug: "lifecycle-active-due",
      retention_until: 2.days.ago,
      discard_candidate_at: 1.day.ago)
    archived_due_document = create(:document,
      project:,
      title: "Lifecycle Archived Due",
      slug: "lifecycle-archived-due",
      retention_until: 3.days.ago)
    archived_due_document.archive!(actor: admin_user)
    excluded_document = create(:document,
      project:,
      title: "Lifecycle Future",
      slug: "lifecycle-future",
      retention_until: 1.month.from_now)

    sign_in_as(admin_user)

    expect do
      get lifecycle_handoff_admin_documents_path(format: :json), params: { q: "LIFE", retention: "due" }
    end.not_to change { document_lifecycle_snapshot }

    expect(response).to have_http_status(:ok)
    payload = json_response
    candidates = payload.fetch("candidates")
    candidate_by_title = candidates.index_by { |candidate| candidate.fetch("title") }

    expect(payload.fetch("current_filter")).to include("q" => "LIFE", "retention" => "due")
    expect(payload.fetch("total_count")).to eq(2)
    expect(payload.fetch("limit")).to eq(Admin::DocumentsController::LIFECYCLE_HANDOFF_LIMIT)
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("read-only handoff")
    expect(payload.fetch("note")).to include("archive / restore / discard / delete は実行しません")
    expect(payload.fetch("runbook_path")).to eq("docs/文書マスタ運用runbook.md")

    expect(candidate_by_title.keys).to contain_exactly(active_due_document.title, archived_due_document.title)
    expect(candidate_by_title).not_to have_key(excluded_document.title)
    expect(candidate_by_title.fetch(active_due_document.title)).to include(
      "public_id" => active_due_document.public_id,
      "project_code" => "LIFE",
      "project_name" => "Lifecycle Project",
      "slug" => "lifecycle-active-due",
      "status" => "active",
      "review_focus" => "archive_candidate_review",
      "admin_edit_path" => edit_admin_document_path(active_due_document.public_id),
      "public_document_path" => project_document_path(project, active_due_document.slug)
    )
    expect(candidate_by_title.fetch(archived_due_document.title)).to include(
      "public_id" => archived_due_document.public_id,
      "status" => "archived",
      "review_focus" => "restore_candidate_review"
    )
    expect(payload.to_s).not_to include("自動削除", "非可逆")
  end

  it "returns a bounded zero-candidate handoff without implying all-clear" do
    create(:document, title: "Future Retention", retention_until: 1.month.from_now)

    sign_in_as(admin_user)

    get lifecycle_handoff_admin_documents_path(format: :json), params: { retention: "due" }

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("current_filter")).to include("retention" => "due")
    expect(payload.fetch("total_count")).to eq(0)
    expect(payload.fetch("candidates")).to eq([])
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("現在条件で lifecycle handoff 対象はありません")
    expect(payload.fetch("note")).to include("正常保証")
  end

  it "bounds candidates and reports truncation" do
    project = create(:project, code: "LIFE-LIMIT", name: "Lifecycle Limit")
    51.times do |index|
      create(:document,
        project:,
        title: "Lifecycle Limit #{index}",
        slug: "lifecycle-limit-#{index}",
        discard_candidate_at: (index + 1).days.ago)
    end

    sign_in_as(admin_user)

    get lifecycle_handoff_admin_documents_path(format: :json), params: { q: "LIFE-LIMIT", discard: "due" }

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("total_count")).to eq(51)
    expect(payload.fetch("limit")).to eq(50)
    expect(payload.fetch("truncated")).to be(true)
    expect(payload.fetch("candidates").size).to eq(50)
  end

  it "forbids external users" do
    create(:document, retention_until: 1.day.ago)

    sign_in_as(external_user)

    get lifecycle_handoff_admin_documents_path(format: :json), params: { retention: "due" }

    expect(response).to have_http_status(:forbidden)
  end
end
