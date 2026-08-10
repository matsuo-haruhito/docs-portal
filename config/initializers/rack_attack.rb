# frozen_string_literal: true

# Rack::Attack — レート制限・ブルートフォース防止
# https://github.com/rack/rack-attack

# テスト環境ではレート制限を無効にする（テストの安定性確保）
Rack::Attack.enabled = !Rails.env.test?

class Rack::Attack
  # -------------------------------------------------------
  # キャッシュストア（Rails.cache を使用）
  # -------------------------------------------------------
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # -------------------------------------------------------
  # セーフリスト: ヘルスチェック
  # -------------------------------------------------------
  safelist("allow-healthcheck") do |request|
    request.path == "/up"
  end

  # -------------------------------------------------------
  # スロットル: 全般的なリクエスト制限（IP単位）
  # -------------------------------------------------------
  # 1分あたり300リクエスト（通常利用で超えることはない）
  throttle("req/ip", limit: 300, period: 1.minute) do |request|
    request.ip unless request.path.start_with?("/assets", "/vite")
  end

  # -------------------------------------------------------
  # スロットル: ログイン試行（ブルートフォース防止）
  # -------------------------------------------------------
  # 同一IPから20回/分に制限
  throttle("logins/ip", limit: 20, period: 1.minute) do |request|
    request.ip if request.path == "/session" && request.post?
  end

  # 同一メールアドレスで5回/分に制限
  throttle("logins/email", limit: 5, period: 1.minute) do |request|
    if request.path == "/session" && request.post?
      request.params.dig("session", "email").to_s.downcase.gsub(/\s+/, "").presence
    end
  end

  # -------------------------------------------------------
  # スロットル: OAuth トークンエンドポイント
  # -------------------------------------------------------
  throttle("oauth/token/ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.path == "/oauth/token" && request.post?
  end

  # -------------------------------------------------------
  # スロットル: API エンドポイント（IP単位）
  # -------------------------------------------------------
  throttle("api/ip", limit: 120, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/api/")
  end

  # -------------------------------------------------------
  # スロットル: 内部 import API（IP単位、重い処理のため厳しめ）
  # -------------------------------------------------------
  throttle("internal_api/ip", limit: 30, period: 1.minute) do |request|
    request.ip if request.path.start_with?("/internal_api/")
  end

  # -------------------------------------------------------
  # ブロック時のレスポンス
  # -------------------------------------------------------
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i

    headers = {
      "Content-Type" => "application/json; charset=utf-8",
      "Retry-After" => retry_after.to_s
    }

    body = {
      error: "リクエスト数が制限を超えました。しばらく待ってから再試行してください。",
      retry_after: retry_after
    }.to_json

    [429, headers, [body]]
  end
end
