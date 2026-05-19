require "rails_helper"

RSpec.describe "Admin generated file bulk retry order", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "bulk retries older failed runs first" do
    sign_in_as(admin_user)
    old_run = create(:generated_file_run, :failed, job_id: "old_job", changed_files: ["old.yml"], created_at: 2.days.ago)
    create(:generated_file_run, :failed, job_id: "new_job", changed_files: ["new.yml"], created_at: 1.day.ago)
    stub_const("Admin::GeneratedFileRunsController::MAX_PER_PAGE", 1)
    allow(GeneratedFileJob).to receive(:perform_later)

    post retry_failed_admin_generated_file_runs_path

    expect(GeneratedFileJob).to have_received(:perform_later).once.with(
      changed_files: ["old.yml"],
      job_ids: ["old_job"],
      event_source: "generated_file_run_bulk_retry",
      metadata: hash_including("retry_of_generated_file_run_public_id" => old_run.public_id)
    )
  end

  it "bulk retries older failed events first" do
    sign_in_as(admin_user)
    old_event = create(:generated_file_event, :failed, path: "old.yml", created_at: 2.days.ago)
    new_event = create(:generated_file_event, :failed, path: "new.yml", created_at: 1.day.ago)
    stub_const("Admin::GeneratedFileEventsController::MAX_PER_PAGE", 1)
    allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

    post retry_failed_admin_generated_file_events_path

    expect(old_event.reload).to be_pending
    expect(new_event.reload).to be_failed
    expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
  end
end
