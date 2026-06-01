module DocumentApprovalRequestsHelper
  DOCUMENT_APPROVAL_REQUEST_STATUS_LABELS = {
    "pending" => "対応待ち",
    "approved" => "OK済み",
    "cancelled" => "Cancel済み"
  }.freeze

  def document_approval_request_table_columns
    [
      table_preferences_column(:created_at, label: "日時", default_width: 160),
      table_preferences_column(:document, label: "文書名", default_width: 240, overflow: :ellipsis),
      table_preferences_column(:title, label: "依頼名", default_width: 240, overflow: :ellipsis, pinned: true),
      table_preferences_column(:requester, label: "依頼者", default_width: 160, overflow: :ellipsis),
      table_preferences_column(:approver, label: "確認相手", default_width: 160, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 120)
    ]
  end

  def document_approval_request_status_label(request_or_value)
    value = request_or_value.respond_to?(:status) ? request_or_value.status : request_or_value
    DOCUMENT_APPROVAL_REQUEST_STATUS_LABELS.fetch(value.to_s) do
      localized_label("document_approval_requests.status", value)
    end
  end
end
