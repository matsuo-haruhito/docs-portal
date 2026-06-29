require "rails_helper"

RSpec.describe "Admin access log filter lookups", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def json_body
    JSON.parse(response.body)
  end

  it "returns bounded project, company, and user options from remote search endpoints" do
    project = create(:project, code: "AUDIT-LOOKUP", name: "Audit Lookup Project")
    company = create(:company, domain: "lookup.example.com", name: "Lookup Company")
    user = create(:user, :internal, company:, name: "Lookup User", email_address: "lookup-user@example.com")
    create(:project, code: "OTHER", name: "Other Project")
    create(:company, domain: "other.example.com", name: "Other Company")
    create(:user, :internal, name: "Other User", email_address: "other-user@example.com")

    sign_in_as(admin_user)

    get project_search_admin_access_logs_path(format: :json), params: { q: "audit-lookup" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => project.id, "text" => "AUDIT-LOOKUP / Audit Lookup Project")
    )

    get company_search_admin_access_logs_path(format: :json), params: { q: "lookup.example" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => company.id, "text" => "Lookup Company / lookup.example.com")
    )

    get user_search_admin_access_logs_path(format: :json), params: { q: "lookup-user" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => user.id, "text" => "Lookup User / lookup-user@example.com")
    )
  end

  it "restores selected project, company, and user options by direct id" do
    project = create(:project, code: "SELECTED", name: "Selected Project")
    company = create(:company, domain: "selected.example.com", name: "Selected Company")
    user = create(:user, :internal, company:, name: "Selected User", email_address: "selected-user@example.com")

    sign_in_as(admin_user)

    get selected_project_admin_access_logs_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => project.id,
      "text" => "SELECTED / Selected Project"
    )

    get selected_company_admin_access_logs_path(format: :json), params: { id: company.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => company.id,
      "text" => "Selected Company / selected.example.com"
    )

    get selected_user_admin_access_logs_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => user.id,
      "text" => "Selected User / selected-user@example.com"
    )
  end

  it "returns nil for unsupported selected ids without leaking unrelated rows" do
    sign_in_as(admin_user)

    get selected_project_admin_access_logs_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get selected_company_admin_access_logs_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get selected_user_admin_access_logs_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "keeps access log lookup endpoints inside the admin boundary" do
    project = create(:project, code: "FORBID", name: "Forbidden Project")
    company = create(:company, domain: "forbidden.example.com", name: "Forbidden Company")
    user = create(:user, :internal, company:, email_address: "forbidden-user@example.com")

    sign_in_as(external_user)

    get project_search_admin_access_logs_path(format: :json), params: { q: project.code }
    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_access_logs_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:forbidden)

    get company_search_admin_access_logs_path(format: :json), params: { q: company.domain }
    expect(response).to have_http_status(:forbidden)

    get selected_company_admin_access_logs_path(format: :json), params: { id: company.id }
    expect(response).to have_http_status(:forbidden)

    get user_search_admin_access_logs_path(format: :json), params: { q: user.email_address }
    expect(response).to have_http_status(:forbidden)

    get selected_user_admin_access_logs_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:forbidden)
  end
end
