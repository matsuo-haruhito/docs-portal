module Admin::RecurringJobSchedulesHelper
  def admin_recurring_job_schedule_table_columns
    [
      table_preferences_column(:job_key, label: "ジョブキー", default_width: 260, overflow: :ellipsis, pinned: true),
      table_preferences_column(:status, label: "定義状態", default_width: 100),
      table_preferences_column(:interval, label: "間隔", default_width: 120),
      table_preferences_column(:next_run_at, label: "次回実行", default_width: 180),
      table_preferences_column(:last_enqueued_at, label: "前回enqueue", default_width: 180),
      table_preferences_column(:last_started_at, label: "前回開始", default_width: 180),
      table_preferences_column(:last_finished_at, label: "前回終了", default_width: 180),
      table_preferences_column(:last_status, label: "前回状態", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 120, pinned: true)
    ]
  end

  def recurring_job_status_badge(status_or_value)
    value = recurring_job_status_value(status_or_value)

    tag.span(
      recurring_job_status_label(value),
      class: ["status-badge", recurring_job_status_class(value)].compact.join(" "),
      style: recurring_job_status_style(value)
    )
  end

  def recurring_job_status_label(status_or_value)
    value = recurring_job_status_value(status_or_value)
    localized_label("recurring_jobs.status", value)
  end

  private

  def recurring_job_status_value(status_or_value)
    value = status_or_value.respond_to?(:status) ? status_or_value.status : status_or_value
    value.presence || "not_run"
  end

  def recurring_job_status_class(status_or_value)
    case recurring_job_status_value(status_or_value)
    when "failed" then "status-danger"
    when "running" then "status-warning"
    when "enqueued" then "status-info"
    else "muted"
    end
  end

  def recurring_job_status_style(status_or_value)
    base = "display:inline-flex;align-items:center;padding:0.18rem 0.6rem;border-radius:999px;border:1px solid transparent;font-size:0.85em;font-weight:600;line-height:1.3;white-space:nowrap;"

    tone = case recurring_job_status_value(status_or_value)
    when "completed"
      "background:#eaf7ee;color:#1f6b3b;border-color:#b7e2c5;"
    when "failed"
      "background:#fdecec;color:#9f1c1c;border-color:#f3b5b5;"
    when "running"
      "background:#fff4e5;color:#9a5a00;border-color:#f2cf97;"
    when "enqueued"
      "background:#eaf3ff;color:#1f5aa6;border-color:#bdd5f5;"
    when "skipped"
      "background:#f4f5f7;color:#57606a;border-color:#d8dee4;"
    else
      "background:#f6f8fa;color:#57606a;border-color:#d8dee4;"
    end

    "#{base}#{tone}"
  end
end
