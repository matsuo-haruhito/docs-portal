namespace :ai_usecases do
  desc "Generate AI usecase decision flow markdown and PlantUML from YAML DSL"
  task generate_flow: :environment do
    ruby Rails.root.join("bin", "generate_ai_usecase_flow").to_s
  end
end

namespace :generated_files do
  desc "Run generated file jobs for changed files. Pass CHANGED_FILES as comma separated paths."
  task run: :environment do
    changed_files = ENV.fetch("CHANGED_FILES", "").split(",").map(&:strip).reject(&:blank?)
    GeneratedFileJob.perform_now(changed_files: changed_files)
  end

  desc "Enqueue generated file jobs for changed files. Pass CHANGED_FILES as comma separated paths."
  task enqueue: :environment do
    changed_files = ENV.fetch("CHANGED_FILES", "").split(",").map(&:strip).reject(&:blank?)
    GeneratedFileJob.perform_later(changed_files: changed_files)
  end

  desc "Run a generated file job by id. Pass JOB_ID."
  task run_job: :environment do
    job_id = ENV.fetch("JOB_ID")
    GeneratedFileJob.perform_now(job_ids: [job_id])
  end

  desc "Enqueue a generated file job by id. Pass JOB_ID."
  task enqueue_job: :environment do
    job_id = ENV.fetch("JOB_ID")
    GeneratedFileJob.perform_later(job_ids: [job_id])
  end
end
