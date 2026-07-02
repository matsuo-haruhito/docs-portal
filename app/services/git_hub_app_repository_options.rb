require "json"
require "net/http"

class GitHubAppRepositoryOptions
  Result = Struct.new(:repositories, :fallback, :message, keyword_init: true) do
    def fallback?
      fallback
    end
  end

  FALLBACK_MESSAGE = "GitHub App repository候補を取得できないため、リポジトリは手入力してください。"
  QUERY_MAX_LENGTH = 100

  def initialize(installation_id:, query:, limit:, client: nil)
    @installation_id = installation_id.to_s.strip
    @query = query.to_s.strip.first(QUERY_MAX_LENGTH)
    @limit = limit.to_i.positive? ? limit.to_i : 20
    @client = client
  end

  def call
    return fallback_result("GitHub App installation ID が未設定のため、リポジトリは手入力してください。") if @installation_id.blank?

    repositories = Array(client.repositories(query: @query, limit: @limit))
      .map { normalize_repository_full_name(_1) }
      .compact
      .uniq
      .first(@limit)

    Result.new(repositories:, fallback: false, message: nil)
  rescue => e
    Rails.logger.info("GitHub App repository options unavailable: #{e.class}: #{e.message}")
    fallback_result(FALLBACK_MESSAGE)
  end

  private

  def client
    @client ||= Client.new(installation_id: @installation_id)
  end

  def fallback_result(message)
    Result.new(repositories: [], fallback: true, message:)
  end

  def normalize_repository_full_name(value)
    repository_full_name = value.to_s.strip
    return nil unless repository_full_name.match?(%r{\A[\w.-]+/[\w.-]+\z})

    repository_full_name
  end

  class Client
    def initialize(installation_id:, token: ENV["GITHUB_APP_INSTALLATION_TOKEN"])
      @installation_id = installation_id
      @token = token.to_s.strip
    end

    def repositories(query:, limit:)
      raise "GitHub App installation token is not configured" if @token.blank?

      uri = URI("https://api.github.com/installation/repositories")
      uri.query = URI.encode_www_form(per_page: [[limit.to_i, 1].max, 100].min)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      raise "GitHub App repository request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      repository_names = Array(parsed["repositories"]).filter_map { _1["full_name"] }
      normalized_query = query.to_s.downcase
      return repository_names if normalized_query.blank?

      repository_names.select { _1.downcase.include?(normalized_query) }
    end
  end
end
