#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "optparse"
require "uri"

module ClosedActiveQueueLabels
  ACTIVE_QUEUE_LABEL_PREFIXES = %w[status: agent:].freeze

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
        url: item["html_url"]
      }
    end
  end

  def format_report(entries)
    return "No closed Issue / PR active queue label drift found." if entries.empty?

    lines = ["Closed Issue / PR active queue label drift found:"]
    entries.each do |entry|
      state_reason = entry[:state_reason] ? ", reason=#{entry[:state_reason]}" : ""
      lines << "- ##{entry[:number]} #{entry[:kind]} state=#{entry[:state]}#{state_reason} labels=#{entry[:labels].join(', ')}"
    end
    lines.join("\n")
  end

  def run(argv:, env:, out:, err:)
    options = { api_url: "https://api.github.com" }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} --repo OWNER/REPO"
      opts.on("--repo REPO", "GitHub repository in OWNER/REPO form") { |repo| options[:repo] = repo }
      opts.on("--api-url URL", "GitHub API URL") { |api_url| options[:api_url] = api_url }
    end
    parser.parse!(argv)

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
