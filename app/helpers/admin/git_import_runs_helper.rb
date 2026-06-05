# frozen_string_literal: true

module Admin::GitImportRunsHelper
  DIAGNOSTIC_PREVIEW_MAX_LENGTH = 240
  SECRET_KEY_PATTERN = /(authorization|token|secret|password|client_secret|access_token|refresh_token|api_key|private_key)/i
  PRIVATE_PATH_PATTERN = %r{(?:[A-Za-z]:[\\/]|/Users/|/home/)[^\s"'<>]+}

  def git_import_run_table_columns
    [
      table_preferences_column(:created_at, label: "実行日時", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:project, label: "案件", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:repository, label: "リポジトリ", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:branch_path, label: "ブランチ/パス", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:commit_sha, label: "コミット", default_width: 140),
      table_preferences_column(:status, label: "状態", default_width: 110, pinned: true),
      table_preferences_column(:summary, label: "実行結果", default_width: 340),
      table_preferences_column(:error_message, label: "エラー", default_width: 340)
    ]
  end

  def git_import_run_summary_lines(run)
    summary = run.summary_json || {}
    deleted_candidates = git_import_summary_value(summary, :deleted_candidates)

    [
      git_import_summary_line(summary, :documents, "取り込み文書"),
      git_import_summary_line(summary, :attachments, "添付"),
      git_import_summary_line(summary, :source_path, "取込元パス"),
      git_import_summary_line(summary, :commit_sha, "commit"),
      git_import_summary_line(summary, :reason, "理由"),
      git_import_summary_line(summary, :publish_job_id, "PublishJob"),
      ("削除候補: #{Array(deleted_candidates).size}" if deleted_candidates.present?)
    ].compact
  end

  def git_import_run_summary_preview_json(run)
    JSON.pretty_generate(sanitize_git_import_run_diagnostic_value(run.summary_json || {}))
  end

  def git_import_run_error_preview(run)
    git_import_run_diagnostic_preview(run.error_message)
  end

  private

  def git_import_summary_line(summary, key, label)
    value = git_import_summary_value(summary, key)
    return if value.blank?

    "#{label}: #{value}"
  end

  def git_import_summary_value(summary, key)
    summary[key.to_s] || summary[key.to_sym]
  end

  def sanitize_git_import_run_diagnostic_value(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), sanitized|
        sanitized[key] = if git_import_run_secret_key?(key)
          "[masked]"
        else
          sanitize_git_import_run_diagnostic_value(nested_value)
        end
      end
    when Array
      value.map { |nested_value| sanitize_git_import_run_diagnostic_value(nested_value) }
    when String
      git_import_run_diagnostic_preview(value)
    else
      value
    end
  end

  def git_import_run_secret_key?(key)
    key.to_s.match?(SECRET_KEY_PATTERN)
  end

  def git_import_run_diagnostic_preview(value)
    sanitized = value.to_s
    sanitized = sanitized.gsub(/\bAuthorization:\s*Bearer\s+[^\s,;]+/i, "Authorization: [masked]")
    sanitized = sanitized.gsub(/\bBearer\s+[^\s,;]+/i, "Bearer [masked]")
    sanitized = sanitized.gsub(/(\b(?:authorization|token|secret|password|client_secret|access_token|refresh_token|api_key|private_key)\b\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)/i) do
      "#{Regexp.last_match(1)}[masked]"
    end
    sanitized = sanitized.gsub(/([?&][^=\s&]*(?:token|secret|password|key)[^=\s&]*=)[^&\s]+/i) do
      "#{Regexp.last_match(1)}[masked]"
    end
    sanitized = sanitized.gsub(PRIVATE_PATH_PATTERN, "[path hidden]")

    truncate_git_import_run_diagnostic(sanitized)
  end

  def truncate_git_import_run_diagnostic(text)
    return text if text.length <= DIAGNOSTIC_PREVIEW_MAX_LENGTH

    "#{text.first(DIAGNOSTIC_PREVIEW_MAX_LENGTH - 3)}..."
  end
end
