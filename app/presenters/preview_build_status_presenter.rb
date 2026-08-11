class PreviewBuildStatusPresenter
  LABELS = {
    preview_not_requested: "未要求",
    preview_queued: "待機中",
    preview_running: "生成中",
    preview_succeeded: "成功",
    preview_failed: "失敗",
    preview_abandoned: "再試行停止"
  }.freeze

  MESSAGES = {
    preview_not_requested: "Docusaurusプレビュー生成はまだ要求されていません。",
    preview_queued: "Docusaurusプレビュー生成を待機しています。",
    preview_running: "Docusaurusプレビューを生成中です。",
    preview_succeeded: "Docusaurusプレビュー生成は完了しています。",
    preview_failed: "Docusaurusプレビュー生成に失敗しました。",
    preview_abandoned: "Docusaurusプレビュー生成は最大試行回数に達したため停止しています。"
  }.freeze

  ARTIFACT_RECOVERY_MESSAGES = {
    preview_not_requested: "生成済みHTMLの成果物復旧はまだ要求されていません。",
    preview_queued: "生成済みHTMLの成果物復旧を待機しています。",
    preview_running: "生成済みHTMLの成果物を復旧中です。",
    preview_succeeded: "生成済みHTMLの成果物復旧は完了しています。",
    preview_failed: "生成済みHTMLの成果物復旧に失敗しました。",
    preview_abandoned: "生成済みHTMLの成果物復旧は最大試行回数に達したため停止しています。"
  }.freeze

  FALLBACK_MESSAGES = {
    preview_not_requested: "生成済みHTMLがないため、元のMarkdownを表示しています。プレビュー生成はまだ要求されていません。",
    preview_queued: "生成済みHTMLがないため、元のMarkdownを表示しています。プレビュー生成を待機しています。",
    preview_running: "生成済みHTMLがないため、元のMarkdownを表示しています。プレビューを生成中です。",
    preview_succeeded: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。後続処理による成果物の復旧を待っています。",
    preview_failed: "生成済みHTMLを利用できないため、元のMarkdownを表示しています。プレビュー生成は自動的に再試行されます。",
    preview_abandoned: "生成済みHTMLを利用できないため、元のMarkdownを表示しています。プレビュー生成の自動再試行は停止しています。"
  }.freeze

  ARTIFACT_RECOVERY_FALLBACK_MESSAGES = {
    preview_not_requested: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。成果物の復旧はまだ要求されていません。",
    preview_queued: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。成果物の復旧を待機しています。",
    preview_running: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。成果物を復旧中です。",
    preview_succeeded: "生成済みHTMLを再度確認できないため、元のMarkdownを表示しています。残りの復旧予算で後続処理を待っています。",
    preview_failed: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。成果物の復旧は自動的に再試行されます。",
    preview_abandoned: "生成済みHTMLを確認できないため、元のMarkdownを表示しています。成果物の自動復旧は上限に達したため停止しています。"
  }.freeze

  BADGE_CLASSES = {
    preview_not_requested: "secondary",
    preview_queued: "warning",
    preview_running: "warning",
    preview_succeeded: "success",
    preview_failed: "danger",
    preview_abandoned: "danger"
  }.freeze

  STATUS_BADGE_STATUSES = {
    preview_not_requested: "pending",
    preview_queued: "warning",
    preview_running: "running",
    preview_succeeded: "success",
    preview_failed: "failed",
    preview_abandoned: "failed"
  }.freeze

  attr_reader :version

  def initialize(version)
    @version = version
  end

  def status
    version.preview_build_status.to_s.to_sym
  end

  def label
    LABELS.fetch(status, LABELS.fetch(:preview_not_requested))
  end

  def message
    messages = artifact_recovery? ? ARTIFACT_RECOVERY_MESSAGES : MESSAGES
    messages.fetch(status, messages.fetch(:preview_not_requested))
  end

  def fallback_message
    messages = artifact_recovery? ? ARTIFACT_RECOVERY_FALLBACK_MESSAGES : FALLBACK_MESSAGES
    messages.fetch(status, messages.fetch(:preview_not_requested))
  end

  def badge_class
    BADGE_CLASSES.fetch(status, BADGE_CLASSES.fetch(:preview_not_requested))
  end

  def status_badge_status
    STATUS_BADGE_STATUSES.fetch(status, STATUS_BADGE_STATUSES.fetch(:preview_not_requested))
  end

  def fallback_label
    succeeded? ? "成果物なし" : label
  end

  def fallback_status_badge_status
    succeeded? ? "warning" : status_badge_status
  end

  def active?
    %i[preview_queued preview_running].include?(status)
  end

  def failed?
    %i[preview_failed preview_abandoned].include?(status)
  end

  def succeeded?
    status == :preview_succeeded
  end

  def artifact_recovery?
    version.preview_build_reason_artifact_recovery?
  end

  def retry_line
    return if version.preview_build_retry_at.blank?

    "次回再試行: #{I18n.l(version.preview_build_retry_at, format: :short)}"
  end

  def recovery_attempt_line
    return unless artifact_recovery?

    "成果物復旧: #{version.preview_build_attempt_count} / #{DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS}回"
  end

  def detail_lines
    [
      attempted_line,
      completed_line,
      retry_line,
      error_line
    ].compact
  end

  private

  def attempted_line
    return if version.preview_build_attempted_at.blank?

    "試行: #{I18n.l(version.preview_build_attempted_at, format: :short)}"
  end

  def completed_line
    return if version.preview_build_completed_at.blank?

    "完了: #{I18n.l(version.preview_build_completed_at, format: :short)}"
  end

  def error_line
    return if version.preview_build_error_message.blank?

    "エラー: #{version.preview_build_error_message}"
  end
end
