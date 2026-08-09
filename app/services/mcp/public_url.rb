module Mcp
  class PublicUrl
    def self.call(request: nil)
      configured = ENV["MCP_PUBLIC_BASE_URL"].to_s.strip
      return configured.delete_suffix("/") if configured.present?
      raise "MCP_PUBLIC_BASE_URL is required in production" if Rails.env.production?
      raise ArgumentError, "request is required when MCP_PUBLIC_BASE_URL is not configured" unless request

      request.base_url
    end
  end
end
