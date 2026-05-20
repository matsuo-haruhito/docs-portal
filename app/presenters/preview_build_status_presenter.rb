class PreviewBuildStatusPresenter
  LABELS = {
    preview_not_requested: "未要求",
    preview_queued: "待機中",
    preview_running: "生成中",
    preview_succeeded: "成功",
    preview_failed: "失敗"
  }.freeze

  MESSAGES = {
    preview_not_requested: "Docusaurusプレビュー生成はまだ要求されていません。",
    preview_queued: "Docusaurusプレビュー生成を待機しています。",
    preview_running: "Docusaurusプレビューを生成中です。",
    preview_succeeded: "Docusaurusプレビュー生成は完了しています。",
    preview_failed: "Docusaurusプレビュー生成に失敗しました。"
  }.freeze

  BADGE_CLASSES = {
    preview_not_requested: "secondary",
    preview_queued: "warning",
    preview_running: "warning",
    preview_succeeded: "success",
    preview_failed: "danger"
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
    MESSAGES.fetch(status, MESSAGES.fetch(:preview_not_requested))
  end

  def badge_class
    BADGE_CLASSES.fetch(status, BADGE_CLASSES.fetch(:preview_not_requested))
  end

  def active?
    %i[preview_queued preview_running].include?(status)
  end

  def failed?
    status == :preview_failed
  end

  def succeeded?
    status == :preview_succeeded
  end

  def detail_lines
    [
      attempted_line,
      completed_line,
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
