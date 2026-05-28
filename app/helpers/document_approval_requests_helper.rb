module DocumentApprovalRequestsHelper
  DOCUMENT_APPROVAL_REQUEST_STATUS_LABELS = {
    "pending" => "対応待ち",
    "approved" => "OK済み",
    "cancelled" => "Cancel済み"
  }.freeze

  def document_approval_request_status_label(request_or_value)
    value = request_or_value.respond_to?(:status) ? request_or_value.status : request_or_value
    DOCUMENT_APPROVAL_REQUEST_STATUS_LABELS.fetch(value.to_s) do
      localized_label("document_approval_requests.status", value)
    end
  end
end
