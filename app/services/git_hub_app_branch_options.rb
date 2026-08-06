require "json"
require "net/http"

class GitHubAppBranchOptions
  Result = Struct.new(:branches, :fallback, :message, keyword_init: true) do
    def fallback?
      fallback
    end
  end

  FALLBACK_MESSAGE = "ブランチ候補を取得できないため、ブランチは手入力してください。"
  BRANCH_LIMIT = 30

  def initialize(installation_id:, repository:, limit: BRANCH_LIMIT, client: nil)
    @installation_id = installation_id.to_s.strip
    @repository = repository.to_s.strip
    @limit = limit.to_i.positive? ? limit.to_i : BRANCH_LIMIT
    @client = client
  end

  def call
    return fallback_result("GitHub App installation ID が未設定のため、ブランチは手入力してください。") if @installation_id.blank?
    return fallback_result("リポジトリが未選択のため、ブランチは手入力してください。") if @repository.blank?

    branches = client.branches(repository: @repository, limit: @limit)
    return fallback_result("ブランチ候補が見つかりません。ブランチは手入力してください。") if branches.empty?

    Result.new(branches:, fallback: false, message: nil)
  rescue => e
    Rails.logger.info("GitHub App branch options unavailable: #{e.class}: #{e.message}")
    fallback_result(FALLBACK_MESSAGE)
  end

  private

  def client
    @client ||= Client.new(installation_id: @installation_id)
  end

  def fallback_result(message)
    Result.new(branches: [], fallback: true, message:)
  end

  class Client
    def initialize(installation_id:, token: ENV["GITHUB_APP_INSTALLATION_TOKEN"])
      @installation_id = installation_id
      @token = token.to_s.strip
    end

    def branches(repository:, limit:)
      raise "GitHub App installation token is not configured" if @token.blank?

      uri = URI("https://api.github.com/repos/#{repository}/branches")
      uri.query = URI.encode_www_form(per_page: [[limit.to_i, 1].max, 100].min)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      raise "GitHub App branch request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      Array(parsed).filter_map { |branch| branch["name"] }.first(limit)
    end
  end
end
