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
    old_event = create(
      :generated_file_event,
      :failed,
      path: "old.yml",
      created_at: 2.days.ago,
      processed_at: 2.hours.ago,
      error_message: "old boom"
    )
    new_event = create(
      :generated_file_event,
      :failed,
      path: "new.yml",
      created_at: 1.day.ago,
      processed_at: 1.hour.ago,
      error_message: "new boom"
    )
    stub_const("Admin::GeneratedFileEventsController::MAX_PER_PAGE", 1)
    allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

    post retry_failed_admin_generated_file_events_path

    old_event.reload
    new_event.reload
    expect(old_event).to be_pending
    expect(old_event.processed_at).to be_nil
    expect(old_event.error_message).to be_nil
    expect(old_event.scheduled_at).to be_within(5.seconds).of(Time.current)
    expect(new_event).to be_failed
    expect(new_event.processed_at).to be_present
    expect(new_event.error_message).to eq("new boom")
    expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
  end
end
