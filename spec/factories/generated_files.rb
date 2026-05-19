FactoryBot.define do
  factory :generated_file_run do
    job_id { "sample_job" }
    generator { "sample_generator" }
    output_writer { "filesystem" }
    status { :completed }
    event_source { "spec" }
    source_paths { ["source.yml"] }
    changed_files { ["source.yml"] }
    generated_paths { ["generated.md"] }
    metadata { {} }
    started_at { 1.minute.ago }
    finished_at { Time.current }

    trait :failed do
      status { :failed }
      error_message { "boom" }
    end
  end

  factory :generated_file_event do
    sequence(:path) { |n| "docs/source-#{n}.yml" }
    operation { "update" }
    event_source { "spec" }
    event_key { GeneratedFileEvent.build_event_key(path: path, operation: operation, event_source: event_source) }
    status { :pending }
    metadata { {} }
    scheduled_at { 1.minute.from_now }
    last_seen_at { Time.current }
    occurrences_count { 1 }

    trait :failed do
      status { :failed }
      scheduled_at { 1.minute.ago }
      processed_at { Time.current }
      error_message { "boom" }
    end

    trait :processed do
      status { :processed }
      scheduled_at { 1.minute.ago }
      processed_at { Time.current }
    end
  end
end
