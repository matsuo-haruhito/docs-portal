module Mcp
  class Authenticator
    SUPPORTED_SCOPES = %w[documents:read documents:write documents:publish].freeze
    Result = Data.define(:user, :access_token, :application, :scopes, :error, :error_code)

    def self.authenticate(request)
      scheme, raw_token = request.headers["Authorization"].to_s.split(" ", 2)
      return failure("Bearerトークンが必要です", "invalid_token") unless scheme&.casecmp("Bearer")&.zero? && raw_token.present?

      token = Doorkeeper::AccessToken.by_token(raw_token)
      return failure("アクセストークンが無効です", "invalid_token") unless token
      return failure("アクセストークンの有効期限が切れています", "invalid_token") if token.expired?
      return failure("アクセストークンは失効しています", "invalid_token") if token.revoked?

      user = User.find_by(id: token.resource_owner_id)
      return failure("ユーザーアカウントが無効です", "invalid_token") unless user&.active?

      scopes = token.scopes.to_a & SUPPORTED_SCOPES
      return failure("文書用OAuthスコープが必要です", "insufficient_scope") if scopes.empty?

      Result.new(user:, access_token: token, application: token.application, scopes:, error: nil, error_code: nil)
    end

    def self.failure(message, code)
      Result.new(user: nil, access_token: nil, application: nil, scopes: [], error: message, error_code: code)
    end
    private_class_method :failure
  end
end
