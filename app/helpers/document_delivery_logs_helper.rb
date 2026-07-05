module DocumentDeliveryLogsHelper
  def document_delivery_log_table_columns
    [
      table_preferences_column(:created_at, label: "作成日時", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:project, label: "案件", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:target, label: "文書名/文書セット名", default_width: 260, overflow: :ellipsis),
      table_preferences_column(:recipients, label: "受信者", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:delivery_type, label: "方式", default_width: 140),
      table_preferences_column(:status, label: "状態", default_width: 120, pinned: true),
      table_preferences_column(:failure_reason, label: "失敗理由", default_width: 280, overflow: :ellipsis)
    ]
  end

  def document_delivery_log_recipient_groups(log)
    [
      ["To", log.to_addresses],
      ["CC", log.cc_addresses],
      ["BCC", log.bcc_addresses]
    ].filter_map do |label, addresses|
      next if addresses.blank?

      [label, addresses]
    end
  end

  def document_delivery_log_detail_link_label(log)
    [
      "送付履歴詳細: #{document_delivery_log_status_label(log)}",
      "案件: #{log.project.name}",
      "対象: #{document_delivery_log_target_label(log)}",
      document_delivery_log_primary_recipient_label(log)
    ].join(" / ")
  end

  def document_delivery_log_target_label(log)
    if log.document.present?
      log.document.title
    elsif log.document_set.present?
      log.document_set.name
    else
      "対象未設定"
    end
  end

  def document_delivery_log_primary_recipient_label(log)
    label, addresses = document_delivery_log_recipient_groups(log).first
    return "宛先: 未設定" if addresses.blank?

    "#{label}: #{addresses}"
  end
end
