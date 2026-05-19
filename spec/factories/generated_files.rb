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
  end

  factory :generated_file_event do
    path { "docs/source.yml" }
    operation { "update" }
    event_source { "spec" }
    sequence(:event_key) { |n| "docs/source.yml:update:spec:#{n}" }
    status { :pending }
    metadata { {} }
    scheduled_at { 1.minute.from_now }
    last_seen_at { Time.current }
    occurrences_count { 1 }
  end
end
