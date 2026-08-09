# frozen_string_literal: true

Rails.application.config.after_initialize do
  Doorkeeper::Application.class_eval do
    validate :validate_secure_redirect_uris

    private

    def validate_secure_redirect_uris
      redirect_uri.to_s.lines(chomp: true).map(&:strip).reject(&:blank?).each do |value|
        uri = URI.parse(value)
        errors.add(:redirect_uri, "にフラグメントは指定できません") if uri.fragment.present? || value.include?("#")

        localhost = %w[localhost 127.0.0.1 [::1]].include?(uri.host)
        errors.add(:redirect_uri, "はlocalhost以外でHTTPSを使用してください") unless uri.scheme == "https" || localhost
      rescue URI::InvalidURIError
        errors.add(:redirect_uri, "は有効なURIではありません")
      end
    end
  end

  Doorkeeper::TokensController.class_eval do
    after_action :set_mcp_oauth_cors_headers

    private

    def set_mcp_oauth_cors_headers
      response.headers["Access-Control-Allow-Origin"] = "*"
      response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    end
  end
end
