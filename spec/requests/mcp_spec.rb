require "rails_helper"

RSpec.describe "MCP endpoint", type: :request do
  let(:user) { create(:user, :internal) }
  let(:oauth_application) do
    Doorkeeper::Application.create!(
      name: "AIエージェント",
      redirect_uri: "https://agent.example.com/callback",
      scopes: "documents:read documents:write documents:publish",
      confidential: false
    )
  end

  def create_access_token(scopes: "documents:read", resource_owner: user)
    Doorkeeper::AccessToken.create_for(
      application: oauth_application,
      resource_owner:,
      scopes:
    )
  end

  def issue_token(scopes: "documents:read", resource_owner: user)
    create_access_token(scopes:, resource_owner:).plaintext_token
  end

  def post_mcp(payload, token: nil)
    headers = {
      "CONTENT_TYPE" => "application/json",
      "ACCEPT" => "application/json, text/event-stream"
    }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: payload.to_json, headers:
  end

  it "requires an OAuth bearer token and advertises protected resource metadata" do
    post_mcp({ jsonrpc: "2.0", id: 1, method: "initialize", params: {} })

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to include(
      "error" => "invalid_token",
      "error_description" => "Bearerトークンが必要です"
    )
    expect(response.headers["WWW-Authenticate"]).to include("/.well-known/oauth-protected-resource")
  end

  it "handles a stateless MCP initialize request" do
    post_mcp(
      {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: MCP::Configuration::DEFAULT_NEGOTIATED_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: "RSpec", version: "1.0" }
        }
      },
      token: issue_token
    )

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("jsonrpc" => "2.0", "id" => 1)
    expect(response.parsed_body.dig("result", "serverInfo", "name")).to eq("docs-portal")
  end

  it "lists only public MCP tools without exposing database identifiers" do
    post_mcp(
      { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} },
      token: issue_token
    )

    expect(response).to have_http_status(:ok)
    tool_names = response.parsed_body.dig("result", "tools").pluck("name")
    expect(tool_names).to contain_exactly(
      "list_projects",
      "search_documents",
      "get_document",
      "get_project_ai_context",
      "get_document_update_route",
      "preview_document_revision",
      "apply_document_revision",
      "check_document_revision",
      "preview_document_publish",
      "publish_document_revision"
    )
    expect(response.body).not_to include("project_id", "document_id")
  end

  it "rejects write tools when the delegated token has only read scope" do
    post_mcp(
      {
        jsonrpc: "2.0",
        id: 3,
        method: "tools/call",
        params: {
          name: "preview_document_revision",
          arguments: { body: "# 更新" }
        }
      },
      token: issue_token(scopes: "documents:read")
    )

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("result", "isError")).to be(true)
    error = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))
    expect(error).to include(
      "error" => {
        "code" => "insufficient_scope",
        "message" => "必要なOAuthスコープがありません"
      }
    )
  end

  it "rejects expired, revoked, and inactive-user tokens" do
    expired = create_access_token
    expired_raw = expired.plaintext_token
    expired.update_columns(created_at: 2.hours.ago, expires_in: 60)
    post_mcp({ jsonrpc: "2.0", id: 4, method: "tools/list", params: {} }, token: expired_raw)
    expect(response).to have_http_status(:unauthorized)

    revoked = create_access_token
    revoked_raw = revoked.plaintext_token
    revoked.update!(revoked_at: Time.current)
    post_mcp({ jsonrpc: "2.0", id: 5, method: "tools/list", params: {} }, token: revoked_raw)
    expect(response).to have_http_status(:unauthorized)

    inactive = create(:user, :external, active: true)
    inactive_raw = issue_token(resource_owner: inactive)
    inactive.update!(active: false)
    post_mcp({ jsonrpc: "2.0", id: 6, method: "tools/list", params: {} }, token: inactive_raw)
    expect(response).to have_http_status(:unauthorized)
  end

  it "keeps external and company master users inside their existing project scope" do
    inaccessible_project = create(:project)

    %i[external company_master_admin].each_with_index do |user_type, index|
      delegated_user = create(:user, user_type)
      accessible_project = create(:project)
      create(:project_membership, project: accessible_project, user: delegated_user)
      create(:document, project: accessible_project, visibility_policy: :public_with_login)

      post_mcp(
        { jsonrpc: "2.0", id: 10 + index, method: "tools/call", params: { name: "list_projects", arguments: {} } },
        token: issue_token(resource_owner: delegated_user)
      )

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))
      project_codes = payload.fetch("projects").pluck("code")
      expect(project_codes).to include(accessible_project.code)
      expect(project_codes).not_to include(inaccessible_project.code)
    end
  end
end
