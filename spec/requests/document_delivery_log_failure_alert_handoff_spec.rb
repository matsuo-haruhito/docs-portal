require "rails_helper"

RSpec.describe "Document delivery log failure alert handoff", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:) }

  def parsed_json
    JSON.parse(response.body)
  end

  def create_delivery_failure(created_at:, to_addresses: "client@example.com", subject: "Document delivery", error_message: "boom")
    create(
      :document_delivery_log,
      project: project,
      document: document,
      sender: internal_user,
      status: :failed,
      delivery_type: :portal_link,
      to_addresses: to_addresses,
      subject: subject,
      error_message: error_message
    ).tap do |log|
      log.update_columns(created_at: created_at, updated_at: created_at)
    end
  end

  it "returns read-only handoff payloads for internal users without exposing raw secrets" do
    create_delivery_failure(
      created_at: 1.hour.ago,
      to_addresses: "client@example.com token=recipient-raw",
      subject: "Document delivery secret=subject-raw",
      error_message: "Authorization: Bearer bearer-raw token=token-raw secret=secret-raw"
    )
    create_delivery_failure(created_at: 2.hours.ago, subject: "Document delivery secret=subject-raw")
    create_delivery_failure(created_at: 3.hours.ago, subject: "Document delivery secret=subject-raw")

    sign_in_as(internal_user)

    get failure_alert_handoff_document_delivery_logs_path(format: :json)

    expect(response).to have_http_status(:ok)
    payload = parsed_json
    expect(payload).to include(
      "count" => 1,
      "runbook_path" => "docs/外部送付履歴継続失敗候補runbook.md"
    )
    expect(payload.fetch("note")).to include("read-only")

    entry = payload.fetch("entries").first
    expect(entry).to include(
      "project_code" => "DLV1",
      "project_name" => "Delivery Project",
      "delivery_type" => "portal_link",
      "failure_count" => 3,
      "runbook_path" => "docs/外部送付履歴継続失敗候補runbook.md"
    )
    expect(entry.fetch("recipient_preview")).to include("token=[FILTERED]")
    expect(entry.fetch("subject_preview")).to include("secret=[FILTERED]")
    expect(entry.fetch("latest_error_message")).to include("Authorization: Bearer [FILTERED]")
    expect(entry.fetch("failed_delivery_logs_path")).to include("%5BFILTERED%5D")

    response_text = response.body
    expect(response_text).not_to include("recipient-raw")
    expect(response_text).not_to include("subject-raw")
    expect(response_text).not_to include("bearer-raw")
    expect(response_text).not_to include("token-raw")
    expect(response_text).not_to include("secret-raw")
  end

  it "returns a bounded empty handoff message without implying healthy monitoring" do
    sign_in_as(internal_user)

    get failure_alert_handoff_document_delivery_logs_path(format: :json)

    expect(response).to have_http_status(:ok)
    expect(parsed_json).to include(
      "count" => 0,
      "entries" => [],
      "note" => "current 条件で handoff 対象なし。これは正常保証、外部監視 green、通知正常を意味しません。"
    )
  end

  it "does not expose the cross-log handoff payload to external users" do
    create_delivery_failure(created_at: 1.hour.ago)
    create_delivery_failure(created_at: 2.hours.ago)
    create_delivery_failure(created_at: 3.hours.ago)
    sign_in_as(external_user)

    get failure_alert_handoff_document_delivery_logs_path(format: :json)

    expect(response).to have_http_status(:forbidden)
  end
end