require "rails_helper"

RSpec.describe RecurringJobRunnerJob, type: :job do
  def create_schedule(attributes = {})
    RecurringJobSchedule.create!({
      job_key: "runner_test_#{SecureRandom.hex(4)}",
      job_class: "DocusaurusPreviewBuildReconciliationJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: {"limit" => 1}
    }.merge(attributes))
  end

  def create_locked_run(schedule)
    run = schedule.recurring_job_runs.create!(
      job_key: schedule.job_key,
      job_class: schedule.job_class,
      queue_name: schedule.queue_name,
      args_json: schedule.args_json,
      status: :enqueued,
      scheduled_at: Time.current,
      enqueued_at: Time.current
    )
    schedule.update!(locked_at: Time.current, locked_by: run.public_id)
    run
  end

  it "claims the reservation, executes its class, and releases the schedule" do
    schedule = create_schedule
    run = create_locked_run(schedule)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now)

    described_class.perform_now(run.id)

    expect(DocusaurusPreviewBuildReconciliationJob).to have_received(:perform_now).with(limit: 1)
    expect(run.reload).to have_attributes(status: "completed", error_message: nil)
    expect(run.started_at).to be_present
    expect(run.finished_at).to be_present
    expect(schedule.reload).to have_attributes(locked_at: nil, locked_by: nil, last_status: "completed")
  end

  it "does nothing when a stale reservation was already recovered" do
    schedule = create_schedule
    run = create_locked_run(schedule)
    run.update!(status: :failed, finished_at: Time.current)
    schedule.update!(locked_at: nil, locked_by: nil)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now)

    described_class.perform_now(run.id)

    expect(DocusaurusPreviewBuildReconciliationJob).not_to have_received(:perform_now)
    expect(run.reload).to be_failed
  end

  it "keeps a queued v2 run untouched while the rollout gate is off" do
    schedule = create_schedule(job_key: "reconcile_docusaurus_preview_builds")
    run = create_locked_run(schedule)
    original_run = run.attributes
    original_schedule = schedule.reload.attributes
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now)

    described_class.perform_now(run.id, RecurringJobDefinition::V2_RUNNER_PROTOCOL_VERSION)

    expect(DocusaurusPreviewBuildReconciliationJob).not_to have_received(:perform_now)
    expect(run.reload.attributes).to eq(original_run)
    expect(schedule.reload.attributes).to eq(original_schedule)
  end

  it "keeps an unversioned v2 payload untouched after the gate is enabled" do
    schedule = create_schedule(job_key: "reconcile_docusaurus_preview_builds")
    run = create_locked_run(schedule)
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now)

    described_class.perform_now(run.id)

    expect(DocusaurusPreviewBuildReconciliationJob).not_to have_received(:perform_now)
    expect(run.reload).to be_enqueued
    expect(schedule.reload.locked_by).to eq(run.public_id)
  end

  it "executes a protocol-versioned v2 payload after the gate is enabled" do
    schedule = create_schedule(job_key: "reconcile_docusaurus_preview_builds")
    run = create_locked_run(schedule)
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now)

    described_class.perform_now(run.id, RecurringJobDefinition::V2_RUNNER_PROTOCOL_VERSION)

    expect(DocusaurusPreviewBuildReconciliationJob).to have_received(:perform_now).with(limit: 1)
    expect(run.reload).to be_completed
  end

  it "records a target failure and still releases the schedule" do
    schedule = create_schedule
    run = create_locked_run(schedule)
    allow(DocusaurusPreviewBuildReconciliationJob).to receive(:perform_now).and_raise("target failed")

    expect { described_class.perform_now(run.id) }.to raise_error(RuntimeError)

    expect(run.reload).to be_failed
    expect(run.error_message).to be_present
    expect(schedule.reload).to have_attributes(locked_at: nil, locked_by: nil, last_status: "failed")
  end
end
