module Admin::AccessRequestsHelper
  ACCESS_REQUEST_STATUS_LABELS = {
    "pending" => "承認待ち",
    "approved" => "承認済み",
    "rejected" => "却下",
    "cancelled" => "取消済み"
  }.freeze
  ACCESS_REQUEST_ACCESS_LEVEL_LABELS = {
    "view" => "閲覧",
    "download" => "ダウンロード",
    "manage" => "管理"
  }.freeze
  ACCESS_REQUEST_REQUESTABLE_TYPE_LABELS = {
    "Project" => "案件",
    "Document" => "文書",
    "DocumentFile" => "文書ファイル"
  }.freeze
  DEFAULT_ACCESS_REQUEST_REJECTION_REASON = "承認条件を満たしていないため却下しました".freeze

  def admin_access_request_status_filter_options
    [["すべて", nil]] + AccessRequest.statuses.keys.map do |status|
      [admin_access_request_status_label(status), status]
    end
  end

  def admin_access_request_access_level_filter_options
    [["すべて", nil]] + AccessRequest.requested_access_levels.keys.map do |access_level|
      [admin_access_request_access_level_label(access_level), access_level]
    end
  end

  def admin_access_request_requestable_type_filter_options
    [["すべて", nil]] + AccessRequest::SUPPORTED_REQUESTABLE_TYPES.map do |requestable_type|
      [admin_access_request_requestable_type_label(requestable_type), requestable_type]
    end
  end

  def admin_access_request_status_label(access_request_or_value)
    value = access_request_or_value.respond_to?(:status) ? access_request_or_value.status : access_request_or_value.to_s
    ACCESS_REQUEST_STATUS_LABELS.fetch(value, value)
  end

  def admin_access_request_status_filter_label(status)
    return "すべて" if status.blank?

    admin_access_request_status_label(status)
  end

  def admin_access_request_access_level_label(access_level)
    ACCESS_REQUEST_ACCESS_LEVEL_LABELS.fetch(access_level.to_s, access_level.to_s)
  end

  def admin_access_request_access_level_filter_label(access_level)
    return "すべて" if access_level.blank?

    admin_access_request_access_level_label(access_level)
  end

  def admin_access_request_requestable_type_label(requestable_type)
    ACCESS_REQUEST_REQUESTABLE_TYPE_LABELS.fetch(requestable_type.to_s, requestable_type.to_s)
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

  def admin_access_request_default_rejection_reason
    DEFAULT_ACCESS_REQUEST_REJECTION_REASON
  end
end
