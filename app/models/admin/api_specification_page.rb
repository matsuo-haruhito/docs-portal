require "fileutils"
require "json"
require "open3"
require Rails.root.join("db/seeds/support/docusaurus_runtime_checker")

class Admin::ApiSpecificationPage
  SITE_PATH = "api-specification".freeze
  FAILURE_MESSAGE_MAX_LENGTH = 160
  BUILD_HISTORY_LIMIT = 5

  BuildStatus = Struct.new(
    :state,
    :label,
    :message,
    :recorded_at,
    :success_at,
    :requested_at,
    :build_entry_mtime,
    keyword_init: true
  )

  BuildHistoryEntry = Struct.new(
    :state,
    :label,
    :message,
    :recorded_at,
    :success_at,
    :requested_at,
    :build_entry_mtime,
    keyword_init: true
  )

  PrimarySourcePage = Struct.new(:label, :site_path, :source_path, keyword_init: true)

  PRIMARY_SOURCE_PAGES = [
    { label: "API仕様・連携設定", site_path: SITE_PATH, source_path: "docs-src/api-specification.md" },
    { label: "単体ファイルアップロードAPI", site_path: "client-file-upload-api", source_path: "docs-src/client-file-upload-api.md" },
    { label: "Office preview", site_path: "office-preview", source_path: "docs-src/office-preview.md" },
    { label: "外部フォルダ同期 Webhook 受信仕様", site_path: "external-folder-sync-webhooks", source_path: "docs-src/external-folder-sync-webhooks.md" }
  ].map { |attributes| PrimarySourcePage.new(**attributes).freeze }.freeze

  def initialize(view_context: nil)
    @view_context = view_context
  end

  def title
    "API仕様"
  end

  def site_path
    SITE_PATH
  end

  def source_path
    Rails.root.join("docs-src", "api-specification.md")
  end

  def primary_source_pages
    PRIMARY_SOURCE_PAGES
  end

  def primary_source_paths
    primary_source_pages.map(&:source_path)
  end

  def source_paths
    Dir[source_path.dirname.join("**", "*.md")].map { |path| Pathname.new(path) }
  end

  def build_entry_path
    build_root.join(SITE_PATH, "index.html")
  end

  def available?
    build_entry_path.exist?
  end

  def stale?
    build_freshness_guard.stale?
  end

  def enqueue_build_if_stale!
    enqueued = build_freshness_guard.enqueue_if_stale!
    record_build_requested! if enqueued
    enqueued
  end

  def enqueue_manual_build!
    return false if build_requested?

    build_freshness_guard.request_build!
    ApiSpecificationBuildJob.perform_later
    record_build_requested!
    true
  rescue
    clear_build_request!
    raise
  end

  def clear_build_request!
    build_freshness_guard.clear_build_request!
  end

  def build_requested?
    build_freshness_guard.build_requested?
  end

  def build_status
    if build_requested?
      build_requested_status
    elsif failed_build_status
      failed_build_status
    elsif available? && !stale?
      available_build_status
    else
      stale_or_missing_build_status
    end
  end

  def build_history
    entries = build_history_marker.filter_map { |payload| build_history_entry(payload) }
    requested_entry = current_requested_history_entry
    entries = [requested_entry, *entries] if requested_entry && entries.none? { |entry| entry.state == :requested && entry.requested_at == requested_entry.requested_at }
    entries.first(BUILD_HISTORY_LIMIT)
  end

  def build!
    raise ActiveRecord::RecordNotFound, "API specification source is missing" unless source_path.exist?

    SeedSupport::DocusaurusRuntimeChecker.ensure_npm!
    FileUtils.mkdir_p(build_root)
    stdout, stderr, status = Open3.capture3(
      { "DOCUSAURUS_DOCS_PATH" => source_path.dirname.to_s },
      "npm", "run", "build",
      chdir: docusaurus_root.to_s
    )
    if status.success? && build_entry_path.exist?
      record_build_success!
      return
    end

    raise "API specification Docusaurus build failed: #{stderr.presence || stdout}"
  rescue => error
    record_build_failure!(error.message)
    raise
  end

  def iframe_src
    @view_context.site_admin_api_specification_path(site_path: SITE_PATH)
  end

  def renderer
    DocusaurusSiteRenderer.new(
      version: docusaurus_version,
      view_context: @view_context,
      embedded: true,
      site_url_builder: lambda { |relative_path, _version| @view_context.site_admin_api_specification_path(site_path: relative_path) }
    )
  end

  private

  def build_requested_status
    BuildStatus.new(
      state: :requested,
      label: "build 待ち/実行中",
      message: "Docusaurus build を開始しています。完了後に再読み込みしてください。",
      requested_at: build_request_marker_mtime
    )
  end

  def failed_build_status
    status = build_status_marker
    return unless status["status"] == "failed"

    BuildStatus.new(
      state: :failed,
      label: "build 失敗",
      message: status["message"].presence || fallback_failure_message,
      recorded_at: parse_marker_time(status["recorded_at"])
    )
  end

  def available_build_status
    status = build_status_marker
    BuildStatus.new(
      state: :available,
      label: "最新 build 成功",
      message: "生成済みHTMLは最新です。必要に応じて再読み込みして表示を確認してください。",
      recorded_at: parse_marker_time(status["recorded_at"]),
      success_at: parse_marker_time(status["success_at"]) || build_entry_path.mtime,
      build_entry_mtime: build_entry_path.mtime
    )
  end

  def stale_or_missing_build_status
    BuildStatus.new(
      state: :stale,
      label: "HTML未生成または stale",
      message: "HTMLが未生成、またはMarkdownより古い状態です。build 開始後、完了してから再読み込みしてください。",
      build_entry_mtime: (build_entry_path.mtime if build_entry_path.exist?)
    )
  end

  def record_build_success!
    now = Time.current
    payload = {
      status: "success",
      recorded_at: now.iso8601,
      success_at: now.iso8601,
      build_entry_mtime: build_entry_path.mtime.iso8601
    }
    write_build_status_marker(payload)
    append_build_history!(payload)
  end

  def record_build_failure!(message)
    payload = {
      status: "failed",
      recorded_at: Time.current.iso8601,
      message: sanitize_failure_message(message)
    }
    write_build_status_marker(payload)
    append_build_history!(payload)
  end

  def record_build_requested!
    requested_at = build_request_marker_mtime || Time.current
    append_build_history!(
      status: "requested",
      recorded_at: Time.current.iso8601,
      requested_at: requested_at.iso8601
    )
  end

  def write_build_status_marker(payload)
    FileUtils.mkdir_p(build_status_marker_path.dirname)
    File.write(build_status_marker_path, JSON.pretty_generate(payload))
  end

  def append_build_history!(payload)
    FileUtils.mkdir_p(build_history_marker_path.dirname)
    history = [payload.stringify_keys, *build_history_marker].first(BUILD_HISTORY_LIMIT)
    File.write(build_history_marker_path, JSON.pretty_generate(history))
  end

  def build_status_marker
    return {} unless build_status_marker_path.exist?

    JSON.parse(build_status_marker_path.read)
  rescue JSON::ParserError
    {}
  end

  def build_history_marker
    return [] unless build_history_marker_path.exist?

    payload = JSON.parse(build_history_marker_path.read)
    payload.is_a?(Array) ? payload : []
  rescue JSON::ParserError
    []
  end

  def build_history_entry(payload)
    status = payload["status"].to_s
    state = build_history_state(status)
    return unless state

    BuildHistoryEntry.new(
      state:,
      label: build_history_label(state),
      message: payload["message"].presence,
      recorded_at: parse_marker_time(payload["recorded_at"]),
      success_at: parse_marker_time(payload["success_at"]),
      requested_at: parse_marker_time(payload["requested_at"]),
      build_entry_mtime: parse_marker_time(payload["build_entry_mtime"])
    )
  end

  def current_requested_history_entry
    return unless build_requested?

    requested_at = build_request_marker_mtime
    BuildHistoryEntry.new(
      state: :requested,
      label: build_history_label(:requested),
      recorded_at: requested_at,
      requested_at:
    )
  end

  def build_history_state(status)
    case status
    when "success"
      :available
    when "failed"
      :failed
    when "requested"
      :requested
    end
  end

  def build_history_label(state)
    case state
    when :available
      "最新 build 成功"
    when :failed
      "build 失敗"
    when :requested
      "build 待ち/実行中"
    end
  end

  def sanitize_failure_message(message)
    sanitized = message.to_s
      .gsub(Rails.root.to_s, "[APP_ROOT]")
      .gsub(%r{/(?:[A-Za-z0-9._-]+/){2,}[A-Za-z0-9._-]+}, "[path]")
      .gsub(/(token|secret|password|api[_-]?key)=\S+/i, "\\1=[FILTERED]")
      .squish
      .truncate(FAILURE_MESSAGE_MAX_LENGTH)

    sanitized.presence || fallback_failure_message
  end

  def fallback_failure_message
    "Docusaurus build に失敗しました。source と runtime の状態を確認してください。"
  end

  def parse_marker_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def build_request_marker_mtime
    build_request_marker_path.mtime if build_request_marker_path.exist?
  end

  def docusaurus_root
    Rails.root.join("docusaurus")
  end

  def build_root
    docusaurus_root.join("build")
  end

  def build_request_marker_path
    Rails.root.join("tmp", "api_specification_build.requested")
  end

  def build_status_marker_path
    Rails.root.join("tmp", "api_specification_build.status.json")
  end

  def build_history_marker_path
    Rails.root.join("tmp", "api_specification_build.history.json")
  end

  def build_freshness_guard
    @build_freshness_guard ||= BuildFreshnessGuard.new(
      source_path:,
      source_paths:,
      build_entry_path:,
      marker_path: build_request_marker_path,
      job_class: ApiSpecificationBuildJob
    )
  end

  def docusaurus_version
    Admin::ApiSpecificationPage::DocusaurusVersion.new(build_root:, entry_path: SITE_PATH)
  end

  DocusaurusVersion = Struct.new(:build_root, :entry_path, keyword_init: true) do
    def site_root_absolute_path
      build_root
    end

    def site_entry_relative_path
      entry_path
    end

    def site_entry_absolute_path
      build_root.join(entry_path, "index.html")
    end

    def legacy_html_absolute_path
      build_root.join("index.html")
    end

    def site_build_path
      entry_path
    end

    def html_view_site_path
      entry_path
    end
  end
end
