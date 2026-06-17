require "rails_helper"

RSpec.describe "Admin access log export metadata", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company, name: "Audit Admin", email_address: "admin@audit.example.com") }

  def parsed_metadata
    JSON.parse(response.body)
  end

  it "returns normalized CSV companion metadata for representative filters" do
    project = create(:project, code: "META", name: "Metadata Project")
    company = create(:company, domain: "metadata.example.com", name: "Metadata Co")
    user = create(:user, :internal, company:, name: "Metadata User", email_address: "metadata-user@example.com")
    normalized_query = "x" * Admin::AccessLogsController::ACCESS_LOG_QUERY_MAX_LENGTH
    long_query = "  #{normalized_query}ignored-suffix  "

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :json), params: {
      action_type: "download",
      target_type: "zip",
      project_id: project.id,
      company_id: company.id,
      user_id: user.id,
      q: long_query,
      document_q: "  Evidence Binder  ",
      from: "not-a-date",
      to: "2026-05-12"
    }

    expect(response).to have_http_status(:ok)

    metadata = parsed_metadata

    expect(metadata).to include(
      "report_type" => "access_logs",
      "row_limit" => 200,
      "export_scope" => "current_filter_latest_rows"
    )
    expect(metadata["description"]).to include("表示中ページではなく")
    expect(metadata["ignored_filters"]).to eq(["from"])
    expect(metadata["filters"]).to include(
      "action_type" => "download",
      "target_type" => "zip",
      "project_id" => project.id.to_s,
      "project" => { "code" => "META", "name" => "Metadata Project" },
      "company_id" => company.id.to_s,
      "company" => { "name" => "Metadata Co", "domain" => "metadata.example.com" },
      "user_id" => user.id.to_s,
      "user" => { "name" => "Metadata User", "email" => "metadata-user@example.com" },
      "q" => normalized_query,
      "document_q" => "Evidence Binder",
      "to" => "2026-05-12"
    )
    expect(metadata["filters"]).not_to have_key("from")
    expect(metadata["summary"]).to include("条件: action_type, target_type, project_id, company_id, user_id, q, document_q, to")
    expect(metadata["summary"]).to include("無効な日付条件を除外: from")
  end

  it "keeps AI context metadata filters only for the AI context target type" do
    sign_in_as(admin_user)

    get admin_access_logs_path(format: :json), params: {
      target_type: "ai_context",
      ai_context_mode: "compact",
      ai_context_scope: "selected"
    }

    expect(response).to have_http_status(:ok)
    ai_context_filters = parsed_metadata.fetch("filters")

    expect(ai_context_filters).to include(
      "target_type" => "ai_context",
      "ai_context_mode" => "compact",
      "ai_context_scope" => "selected"
    )

    get admin_access_logs_path(format: :json), params: {
      target_type: "zip",
      ai_context_mode: "compact",
      ai_context_scope: "selected"
    }

    expect(response).to have_http_status(:ok)
    zip_filters = parsed_metadata.fetch("filters")

    expect(zip_filters).to include("target_type" => "zip")
    expect(zip_filters).not_to have_key("ai_context_mode")
    expect(zip_filters).not_to have_key("ai_context_scope")
  end
end
