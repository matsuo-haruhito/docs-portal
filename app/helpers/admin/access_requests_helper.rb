module Admin::AccessRequestsHelper
  ACCESS_REQUEST_STATUS_LABELS = {
    "pending" => "承認待ち",
    "approved" => "承認済み",
    "rejected" => "却下",
    "cancelled" => "取消済み"
  }.freeze
  ACCESS_REQUESTABLE_TYPE_LABELS = {
    "Project" => "案件",
    "Document" => "文書",
    "DocumentFile" => "添付ファイル"
  }.freeze
  DEFAULT_ACCESS_REQUEST_REJECTION_REASON = "承認条件を満たしていないため却下しました".freeze
  ACCESS_REQUEST_REJECTION_REASON_PRESET_OPTIONS = [
    ["権限不足", "permission_shortage"],
    ["対象誤り", "wrong_target"],
    ["情報不足", "insufficient_information"],
    ["承認条件不一致", "approval_mismatch"]
  ].freeze
  DEFAULT_ACCESS_REQUEST_REJECTION_REASON_PRESET = "approval_mismatch".freeze

  def admin_access_request_table_columns
    [
      table_preferences_column(:created_at, label: "申請日時", default_width: 160, pinned: true, sortable: true),
      table_preferences_column(:processed_at, label: "処理日時", default_width: 180),
      table_preferences_column(:requester, label: "申請者", default_width: 260, pinned: true, overflow: :ellipsis),
      table_preferences_column(:target, label: "対象", default_width: 280, pinned: true, overflow: :ellipsis),
      table_preferences_column(:requested_access_level, label: "要求権限", default_width: 160),
      table_preferences_column(:status, label: "状態", default_width: 120, pinned: true),
      table_preferences_column(:reason, label: "理由", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:approver, label: "承認者", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:actions, label: "操作", default_width: 160, pinned: true)
    ]
  end

  def admin_access_request_status_filter_options
    [["すべて", nil]] + AccessRequest.statuses.keys.map do |status|
      [admin_access_request_status_label(status), status]
    end
  end

  def admin_access_request_access_level_filter_options
    [["すべて", nil]] + AccessRequest.requested_access_levels.keys.map do |access_level|
      [document_permission_access_level_label(access_level), access_level]
    end
  end

  def admin_access_request_requestable_type_filter_options
    [["すべて", nil]] + AccessRequest::SUPPORTED_REQUESTABLE_TYPES.map do |requestable_type|
      [admin_access_request_requestable_type_label(requestable_type), requestable_type]
    end
  end

  def admin_access_request_rejection_reason_preset_options
    ACCESS_REQUEST_REJECTION_REASON_PRESET_OPTIONS
  end

  def admin_access_request_default_rejection_reason_preset
    DEFAULT_ACCESS_REQUEST_REJECTION_REASON_PRESET
  end

  def admin_access_request_status_label(access_request_or_value)
    value = access_request_or_value.respond_to?(:status) ? access_request_or_value.status : access_request_or_value.to_s
    ACCESS_REQUEST_STATUS_LABELS.fetch(value, value)
  end

  def admin_access_request_status_filter_label(status)
    return "すべて" if status.blank?

    admin_access_request_status_label(status)
  end

  def admin_access_request_access_level_filter_label(access_level)
    return "すべて" if access_level.blank?

    document_permission_access_level_label(access_level)
  end

  def admin_access_request_requestable_type_label(requestable_type)
    ACCESS_REQUESTABLE_TYPE_LABELS.fetch(requestable_type.to_s, requestable_type.to_s)
  end

  def admin_access_request_requestable_type_filter_label(requestable_type)
    return "すべて" if requestable_type.blank?

    admin_access_request_requestable_type_label(requestable_type)
  end

  def admin_access_request_primary_target_label(requestable)
    requestable[:name].presence || requestable[:title].presence || requestable[:file_name].presence || requestable[:public_id]
  end

  def admin_access_request_secondary_target_label(requestable)
    return requestable[:code] if requestable[:code].present?
    return requestable[:project_code] if requestable[:project_code].present?
    return requestable[:document_title] if requestable[:document_title].present?

    nil
  end

  def admin_access_request_processed_at_label(access_request)
    case access_request.status
    when "approved"
      "承認日時"
    when "rejected"
      "却下日時"
    when "cancelled"
      "取消日時"
    end
  end

  def admin_access_request_processed_at(access_request)
    case access_request.status
    when "approved"
      access_request.approved_at
    when "rejected"
      access_request.rejected_at
    when "cancelled"
      access_request.cancelled_at
    end
  end

  def admin_access_request_default_rejection_reason
    DEFAULT_ACCESS_REQUEST_REJECTION_REASON
  end
end
