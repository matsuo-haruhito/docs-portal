module Admin::AccessRequestsHelper
  ACCESS_REQUEST_STATUS_LABELS = {
    "pending" => "承認待ち",
    "approved" => "承認済み",
    "rejected" => "却下",
    "cancelled" => "取消済み"
  }.freeze

  def admin_access_request_status_filter_options
    [["すべて", nil]] + AccessRequest.statuses.keys.map do |status|
      [admin_access_request_status_label(status), status]
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

  def admin_access_request_primary_target_label(requestable)
    requestable[:name].presence || requestable[:title].presence || requestable[:file_name].presence || requestable[:public_id]
  end

  def admin_access_request_secondary_target_label(requestable)
    return requestable[:code] if requestable[:code].present?
    return requestable[:project_code] if requestable[:project_code].present?
    return requestable[:document_title] if requestable[:document_title].present?

    nil
  end
end
