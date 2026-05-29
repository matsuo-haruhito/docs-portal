# frozen_string_literal: true

module Admin::GitImportRunsHelper
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

  private

  def git_import_summary_line(summary, key, label)
    value = git_import_summary_value(summary, key)
    return if value.blank?

    "#{label}: #{value}"
  end

  def git_import_summary_value(summary, key)
    summary[key.to_s] || summary[key.to_sym]
  end
end
