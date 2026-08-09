require "rails_helper"

RSpec.describe "OAuth metadata", type: :request do
  it "publishes the authorization server and protected resource metadata" do
    get "/.well-known/oauth-authorization-server"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "issuer" => "http://localhost",
      "authorization_endpoint" => "http://localhost/oauth/authorize",
      "token_endpoint" => "http://localhost/oauth/token",
      "code_challenge_methods_supported" => ["S256"],
      "scopes_supported" => %w[documents:read documents:write documents:publish]
    )

    get "/.well-known/oauth-protected-resource"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "resource" => "http://localhost/mcp",
      "authorization_servers" => ["http://localhost"],
      "bearer_methods_supported" => ["header"]
    )
  end

  it "allows localhost redirects and rejects insecure external redirects" do
    localhost_application = Doorkeeper::Application.new(
      name: "ローカルクライアント",
      redirect_uri: "http://localhost:6274/callback",
      scopes: "documents:read",
      confidential: false
    )
    insecure_application = Doorkeeper::Application.new(
      name: "安全でないクライアント",
      redirect_uri: "http://agent.example.com/callback",
      scopes: "documents:read",
      confidential: false
    )

    expect(localhost_application).to be_valid
    expect(insecure_application).not_to be_valid
    expect(insecure_application.errors[:redirect_uri]).to include("はlocalhost以外でHTTPSを使用してください")
  end

  it "returns token endpoint CORS headers for preflight requests" do
    options "/oauth/token"

    expect(response).to have_http_status(:no_content)
    expect(response.headers).to include(
      "Access-Control-Allow-Origin" => "*",
      "Access-Control-Allow-Methods" => "POST, OPTIONS",
      "Access-Control-Allow-Headers" => "Content-Type, Authorization"
    )
  end
end
