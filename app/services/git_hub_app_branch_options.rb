require "json"
require "net/http"

class GitHubAppBranchOptions
  Result = Struct.new(:branches, :fallback, :message, keyword_init: true) do
    def fallback?
      fallback
    end
  end

  FALLBACK_MESSAGE = "GitHub App branch候補を取得できないため、ブランチは手入力してください。"
  QUERY_MAX_LENGTH = 100

  def initialize(installation_id:, repository_full_name:, query:, limit:, client: nil)
    @installation_id = installation_id.to_s.strip
    @repository_full_name = normalize_repository_full_name(repository_full_name)
    @query = query.to_s.strip.first(QUERY_MAX_LENGTH)
    @limit = limit.to_i.positive? ? limit.to_i : 20
    @client = client
  end

  def call
    return fallback_result("GitHub App installation ID が未設定のため、ブランチは手入力してください。") if @installation_id.blank?
    return fallback_result("リポジトリが未選択のため、ブランチは手入力してください。") if @repository_full_name.blank?

    result = client.branches(repository_full_name: @repository_full_name, query: @query, limit: @limit)
    branches = Array(result[:branches])
      .map { normalize_branch_name(_1) }
      .compact
      .uniq
    branches = prioritize_default_branch(branches, result[:default_branch]).first(@limit)
    return fallback_result("条件に一致する GitHub App branch候補がないため、ブランチは手入力してください。") if branches.empty?

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

  def normalize_repository_full_name(value)
    repository_full_name = value.to_s.strip
    return nil unless repository_full_name.match?(%r{\A[\w.-]+/[\w.-]+\z})

    repository_full_name
  end

  def normalize_branch_name(value)
    branch_name = value.to_s.strip
    branch_name.presence&.first(QUERY_MAX_LENGTH)
  end

  def prioritize_default_branch(branches, default_branch)
    default_branch = normalize_branch_name(default_branch)
    return branches if default_branch.blank?

    branches.sort_by { |branch| branch == default_branch ? 0 : 1 }
  end

  class Client
    def initialize(installation_id:, token: ENV["GITHUB_APP_INSTALLATION_TOKEN"])
      @installation_id = installation_id
      @token = token.to_s.strip
    end

    def branches(repository_full_name:, query:, limit:)
      raise "GitHub App installation token is not configured" if @token.blank?

      owner, repo = repository_full_name.split("/", 2)
      repository = request_json("/repos/#{owner}/#{repo}")
      branches = request_json("/repos/#{owner}/#{repo}/branches", per_page: [[limit.to_i, 1].max, 100].min)
      branch_names = Array(branches).filter_map { _1["name"] }
      normalized_query = query.to_s.downcase
      branch_names = branch_names.select { _1.downcase.include?(normalized_query) } if normalized_query.present?

      { branches: branch_names, default_branch: repository["default_branch"] }
    end

    private

    def request_json(path, query = {})
      uri = URI("https://api.github.com#{path}")
      uri.query = URI.encode_www_form(query) if query.present?
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      raise "GitHub App branch request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
