#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "uri"

module ClosedActiveQueueLabels
  ACTIVE_QUEUE_LABEL_PREFIXES = %w[status: agent:].freeze
  RECOMMENDED_ACTION = "review_item_then_remove_stale_status_agent_labels".freeze

  class Error < StandardError; end

  class GitHubClient
    def initialize(repo:, token:, api_url: "https://api.github.com")
      @repo = repo
      @token = token
      @api_url = api_url
    end

    def each_closed_item
      return enum_for(:each_closed_item) unless block_given?

      page = 1
      loop do
        items = get_json("/repos/#{@repo}/issues", state: "closed", per_page: 100, page: page)
        break if items.empty?

        items.each { |item| yield item }
        page += 1
      end
    end

    private

    def get_json(path, params)
      uri = URI.join(@api_url, path)
      uri.query = URI.encode_www_form(params)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "GitHub API request failed: #{response.code} #{response.message}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "GitHub API response was not valid JSON: #{error.message}"
    end
  end

  module_function

  def active_queue_labels(labels)
    labels.filter_map do |label|
      name = label.is_a?(Hash) ? label["name"] : label.to_s
      name if ACTIVE_QUEUE_LABEL_PREFIXES.any? { |prefix| name.start_with?(prefix) }
    end
  end

  def closed_item?(item)
    item.fetch("state") == "closed"
  end

  def item_kind(item)
    item.key?("pull_request") ? "pull_request" : "issue"
  end

  def drift_entries(items)
    items.filter_map do |item|
      next unless closed_item?(item)

      active_labels = active_queue_labels(item.fetch("labels", []))
      next if active_labels.empty?

      {
        number: item.fetch("number"),
        kind: item_kind(item),
        state: item.fetch("state"),
        state_reason: item["state_reason"],
        labels: active_labels,
        recommended_action: RECOMMENDED_ACTION,
        url: item["html_url"]
      }
    end
  end

  def format_report(entries)
    return "No closed Issue / PR active queue label drift found." if entries.empty?

    lines = ["Closed Issue / PR active queue label drift digest:"]
    entries.each do |entry|
      state_reason = entry[:state_reason] ? ", reason=#{entry[:state_reason]}" : ""
      lines << "- ##{entry[:number]} #{entry[:kind]} state=#{entry[:state]}#{state_reason} active_labels=#{entry[:labels].join(', ')} recommended_action=#{entry[:recommended_action]} url=#{entry[:url]}"
    end
    lines.join("\n")
  end

  def self_test_items
    [
      {
        "number" => 101,
        "state" => "closed",
        "state_reason" => "completed",
        "labels" => [{ "name" => "status:ready-for-agent" }, { "name" => "agent:planned" }, { "name" => "track:quality" }],
        "html_url" => "https://github.example.test/repo/issues/101"
      },
      {
        "number" => 102,
        "state" => "closed",
        "state_reason" => nil,
        "labels" => [{ "name" => "risk:low" }],
        "html_url" => "https://github.example.test/repo/issues/102"
      },
      {
        "number" => 103,
        "state" => "open",
        "labels" => [{ "name" => "status:ready-for-agent" }],
        "html_url" => "https://github.example.test/repo/issues/103"
      },
      {
        "number" => 104,
        "state" => "closed",
        "pull_request" => {},
        "labels" => [{ "name" => "agent:needs-review" }],
        "html_url" => "https://github.example.test/repo/pull/104"
      }
    ]
  end

  def run_self_test(out:, err:)
    entries = drift_entries(self_test_items)
    report = format_report(entries)

    expected = [
      "Closed Issue / PR active queue label drift digest:",
      "#101 issue state=closed, reason=completed active_labels=status:ready-for-agent, agent:planned recommended_action=#{RECOMMENDED_ACTION}",
      "#104 pull_request state=closed active_labels=agent:needs-review recommended_action=#{RECOMMENDED_ACTION}"
    ]
    missing = expected.reject { |text| report.include?(text) }
    unwanted = ["#102", "#103", "track:quality"].select { |text| report.include?(text) }

    if missing.any? || unwanted.any?
      err.puts "closed active queue label digest self-test failed"
      missing.each { |text| err.puts "missing expected self-test output: #{text.inspect}" }
      unwanted.each { |text| err.puts "unexpected self-test output: #{text.inspect}" }
      return 1
    end

    out.puts "closed active queue label digest self-test passed."
    0
  end

  def run(argv:, env:, out:, err:)
    options = { api_url: "https://api.github.com", self_test: false }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} --repo OWNER/REPO"
      opts.on("--repo REPO", "GitHub repository in OWNER/REPO form") { |repo| options[:repo] = repo }
      opts.on("--api-url URL", "GitHub API URL") { |api_url| options[:api_url] = api_url }
      opts.on("--self-test", "Run local digest formatting checks without GitHub API access") { options[:self_test] = true }
    end
    parser.parse!(argv)

    return run_self_test(out: out, err: err) if options[:self_test]

    token = env["GITHUB_TOKEN"]
    raise Error, "GITHUB_TOKEN is required for read-only GitHub API access." if token.to_s.empty?
    raise Error, "--repo OWNER/REPO is required." if options[:repo].to_s.empty?

    client = GitHubClient.new(repo: options.fetch(:repo), token: token, api_url: options.fetch(:api_url))
    entries = drift_entries(client.each_closed_item)
    out.puts format_report(entries)
    entries.empty? ? 0 : 1
  rescue Error, OptionParser::ParseError => error
    err.puts error.message
    2
  end
end

if $PROGRAM_NAME == __FILE__
  exit ClosedActiveQueueLabels.run(argv: ARGV, env: ENV, out: $stdout, err: $stderr)
end
