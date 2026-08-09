class McpController < ActionController::API
  def create
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    request_metadata = parsed_request_metadata
    auth = Mcp::Authenticator.authenticate(request)
    return render_unauthorized(auth) unless auth.user

    Current.user = auth.user
    server = Mcp::ServerBuilder.build(user: auth.user, application: auth.application, scopes: auth.scopes)
    transport = build_transport(server)
    request.body.rewind
    transport_status, headers, body = transport.handle_request(request)
    headers.each { |key, value| response.headers[key] = value }
    self.status = transport_status
    self.response_body = body
  ensure
    record_mcp_access(auth, request_metadata, started_at) if defined?(started_at)
    Current.reset
  end

  private

  def build_transport(server)
    base_url = Mcp::PublicUrl.call(request:)
    uri = URI.parse(base_url)
    allowed_hosts = [uri.host, uri.authority].compact.uniq

    ::MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      allowed_hosts:,
      allowed_origins: [base_url]
    )
  end

  def render_unauthorized(auth)
    metadata_url = "#{Mcp::PublicUrl.call(request:)}/.well-known/oauth-protected-resource"
    response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{metadata_url}", error="#{auth.error_code}")
    render json: { error: auth.error_code, error_description: auth.error }, status: :unauthorized
  end

  def parsed_request_metadata
    payload = JSON.parse(request.raw_post)
    request.body.rewind
    {
      method: payload["method"].to_s.first(80),
      tool: payload.dig("params", "name").to_s.first(80),
      request_id: payload["id"].to_s.first(80)
    }
  rescue JSON::ParserError
    { method: "invalid_json", tool: "", request_id: "" }
  end

  def record_mcp_access(auth, metadata, started_at)
    return unless auth&.user

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    client_digest = Digest::SHA256.hexdigest(auth.application&.uid.to_s).first(16)
    AccessLog.create!(
      user: auth.user,
      company: auth.user.company,
      action_type: :view,
      target_type: "mcp",
      target_name: "method=#{metadata[:method]};tool=#{metadata[:tool]};client=#{client_digest};request_id=#{metadata[:request_id]};duration_ms=#{duration_ms}",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("MCP AccessLog skipped: #{e.class}: #{e.message}")
  end
end
