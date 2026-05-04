FactoryBot.define do
  factory :document_file do
    association :document_version
    sequence(:file_name) { |n| "attachment-#{n}.txt" }
    content_type { "text/plain" }
    sequence(:storage_key) { |n| "spec/factory/document-files/attachment-#{n}.txt" }
    file_size { 0 }
    scan_status { :scan_pending }
  end
end
