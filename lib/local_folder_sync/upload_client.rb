# frozen_string_literal: true

require "digest"
require "json"
require "net/http"
require "pathname"
require "uri"

module LocalFolderSync
  class UploadClient
    DEFAULT_ENDPOINT = "/api/internal/file_uploads"

    Config = Data.define(
      :portal_url,
      :token,
      :project_code,
      :sync_root,
      :source_name,
      :file_path,
      :endpoint
    )

    UploadRequest = Data.define(
      :file_path,
      :relative_path,
      :source_path,
      :content_hash,
      :project_code,
      :source_name
    )

    class Error < StandardError; end

    def self.config_from_env(env = ENV)
      Config.new(
        portal_url: env["DOCS_PORTAL_URL"],
        token: env["DOC_IMPORT_TOKEN"],
        project_code: env["DOCS_PORTAL_PROJECT_CODE"],
        sync_root: env["LOCAL_FOLDER_SYNC_ROOT"],
        source_name: env["LOCAL_FOLDER_SYNC_SOURCE_NAME"] || "local-folder-sync",
        file_path: env["LOCAL_FOLDER_SYNC_FILE"],
        endpoint: env["LOCAL_FOLDER_SYNC_ENDPOINT"] || DEFAULT_ENDPOINT
      )
    end

    def initialize(config:, http: Net::HTTP)
      @config = config
      @http = http
    end

    def call
      request = build_upload_request
      response = post_upload(request)
      JSON.parse(response.body).merge(
        "sent_content_hash" => request.content_hash,
        "sent_relative_path" => request.relative_path
      )
    end

    def build_upload_request
      validate_config!

      sync_root = expanded_path(config.sync_root)
      file_path = expanded_path(config.file_path)
      ensure_file_inside_root!(file_path, sync_root)

      relative_path = file_path.relative_path_from(sync_root).to_s.tr("\\", "/")
      ensure_safe_relative_path!(relative_path)

      UploadRequest.new(
        file_path: file_path,
        relative_path: relative_path,
        source_path: file_path.to_s,
        content_hash: Digest::SHA256.file(file_path.to_s).hexdigest,
        project_code: config.project_code,
        source_name: config.source_name
      )
    end

    def summary_for(payload)
      preview = payload.fetch("file_upload_preview", {})

      {
        dry_run_id: payload["dry_run_id"],
        status: payload["status"],
        relative_path: payload["sent_relative_path"],
        sent_content_hash: payload["sent_content_hash"],
        server_content_hash: preview["content_hash"],
        server_hash_matches: !blank?(payload["sent_content_hash"]) &&
          payload["sent_content_hash"] == preview["content_hash"],
        boundary: "dry-run only; apply is performed in docs-portal with import_dry_run_id"
      }
    end

    private

    attr_reader :config, :http

    def validate_config!
      missing = {
        "DOCS_PORTAL_URL" => config.portal_url,
        "DOC_IMPORT_TOKEN" => config.token,
        "DOCS_PORTAL_PROJECT_CODE" => config.project_code,
        "LOCAL_FOLDER_SYNC_ROOT" => config.sync_root,
        "LOCAL_FOLDER_SYNC_FILE" => config.file_path
      }.select { |_name, value| blank?(value) }.keys

      raise Error, "missing required setting(s): #{missing.join(', ')}" if missing.any?
    end

    def post_upload(upload_request)
      uri = upload_uri
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{config.token}"
      request.set_form(
        [
          ["project_code", upload_request.project_code],
          ["relative_path", upload_request.relative_path],
          ["source_name", upload_request.source_name],
          ["source_path", upload_request.source_path],
          ["content_hash", "sha256:#{upload_request.content_hash}"],
          ["file", upload_request.file_path.open("rb"), { filename: File.basename(upload_request.relative_path) }]
        ],
        "multipart/form-data"
      )

      response = http.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |client|
        client.request(request)
      ensure
        request.body_stream&.close
      end

      return response if response.is_a?(Net::HTTPSuccess)

      raise Error, "upload dry-run failed with HTTP #{response.code}"
    end

    def upload_uri
      base = URI.parse(config.portal_url)
      endpoint = config.endpoint || DEFAULT_ENDPOINT
      URI.join(base.to_s.end_with?("/") ? base.to_s : "#{base}/", endpoint.delete_prefix("/"))
    end

    def expanded_path(path)
      Pathname(path).expand_path.cleanpath
    end

    def ensure_file_inside_root!(file_path, sync_root)
      raise Error, "upload target must be a regular file" unless file_path.file?

      file_path.relative_path_from(sync_root)
    rescue ArgumentError
      raise Error, "upload target must be inside sync root"
    end

    def ensure_safe_relative_path!(relative_path)
      segments = relative_path.split("/")
      unsafe = blank?(relative_path) ||
        relative_path == "." ||
        relative_path == ".." ||
        relative_path.start_with?("/") ||
        relative_path.match?(%r{\A[A-Za-z]:/}) ||
        relative_path.include?("\0") ||
        segments.include?("..")

      raise Error, "relative_path is invalid" if unsafe
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
