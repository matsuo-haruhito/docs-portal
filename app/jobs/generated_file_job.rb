class GeneratedFileJob < ApplicationJob
  queue_as :default

  def perform(changed_files: [], job_ids: [])
    GeneratedFiles::Runner.new(changed_files:, job_ids:).call
  end
end
