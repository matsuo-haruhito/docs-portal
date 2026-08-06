require "json"
require "net/http"

class GitHubAppDirectoryOptions
  Result = Struct.new(:directories, :fallback, :message, keyword_init: true) do
    def fallback?
      fallback
    end
  end

  FALLBACK_MESSAGE = "ディレクトリ候補を取得できないため、取込元パスは手入力してください。"
  DIRECTORY_LIMIT = 50

  def initialize(installation_id:, repository:, branch:, limit: DIRECTORY_LIMIT, client: nil)
    @installation_id = installation_id.to_s.strip
    @repository = repository.to_s.strip
    @branch = branch.to_s.strip
    @limit = limit.to_i.positive? ? limit.to_i : DIRECTORY_LIMIT
    @client = client
  end

  def call
    return fallback_result("GitHub App installation ID が未設定のため、取込元パスは手入力してください。") if @installation_id.blank?
    return fallback_result("リポジトリが未選択のため、取込元パスは手入力してください。") if @repository.blank?
    return fallback_result("ブランチが未入力のため、取込元パスは手入力してください。") if @branch.blank?

    directories = client.directories(repository: @repository, branch: @branch, limit: @limit)
    return fallback_result("ディレクトリ候補が見つかりません。取込元パスは手入力してください。") if directories.empty?

    Result.new(directories:, fallback: false, message: nil)
  rescue => e
    Rails.logger.info("GitHub App directory options unavailable: #{e.class}: #{e.message}")
    fallback_result(FALLBACK_MESSAGE)
  end

  private

  def client
    @client ||= Client.new(installation_id: @installation_id)
  end

  def fallback_result(message)
    Result.new(directories: [], fallback: true, message:)
  end

  class Client
    def initialize(installation_id:, token: ENV["GITHUB_APP_INSTALLATION_TOKEN"])
      @installation_id = installation_id
      @token = token.to_s.strip
    end

    def directories(repository:, branch:, limit:)
      raise "GitHub App installation token is not configured" if @token.blank?

      uri = URI("https://api.github.com/repos/#{repository}/git/trees/#{branch}?recursive=1")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      raise "GitHub App tree request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      tree_entries = Array(parsed["tree"])
      tree_entries
        .select { |entry| entry["type"] == "tree" }
        .map { |entry| entry["path"] }
        .sort
        .first(limit)
    end
  end
end
