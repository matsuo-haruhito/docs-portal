FactoryBot.define do
  factory :bulk_edit_dry_run do
    created_by { association :user, :admin }
    operation_type { :document_metadata }
    target_document_ids { [1] }
    params_json { { document_attributes: { category: "manual" } } }
    summary_json { { preview: { total_count: 1, changed_count: 1, unchanged_count: 0, valid_count: 1, invalid_count: 0, warning_count: 0, error_count: 0, target_document_ids: [1] } } }
    result_json { { preview_items: [] } }
    warnings_json { [] }
    errors_json { [] }
    status { :analyzed }
    expires_at { 1.day.from_now }
  end
end
