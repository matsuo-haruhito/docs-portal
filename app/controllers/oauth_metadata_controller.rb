class OauthMetadataController < ActionController::API
  def authorization_server
    base_url = Mcp::PublicUrl.call(request:)
    render json: {
      issuer: base_url,
      authorization_endpoint: "#{base_url}/oauth/authorize",
      token_endpoint: "#{base_url}/oauth/token",
      revocation_endpoint: "#{base_url}/oauth/revoke",
      response_types_supported: ["code"],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: %w[client_secret_post none],
      scopes_supported: %w[documents:read documents:write documents:publish]
    }
  end

  def protected_resource
    base_url = Mcp::PublicUrl.call(request:)
    render json: {
      resource: "#{base_url}/mcp",
      authorization_servers: [base_url],
      bearer_methods_supported: ["header"],
      scopes_supported: %w[documents:read documents:write documents:publish]
    }
  end
end
