require "rails_helper"

RSpec.describe RecurringJobDispatcherJob, type: :job do
  before do
    allow(RecurringJobDefinition).to receive(:all).and_return([])
  end

  def create_schedule(attributes = {})
    RecurringJobSchedule.create!({
      job_key: "test_job_#{SecureRandom.hex(4)}",
      job_class: "DocusaurusPreviewBuildReconciliationJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: {"limit" => 1}
    }.merge(attributes))
  end

  def create_run(schedule, attributes = {})
    schedule.recurring_job_runs.create!({
      job_key: schedule.job_key,
      job_class: schedule.job_class,
      queue_name: schedule.queue_name,
      args_json: schedule.args_json,
      status: :enqueued,
      scheduled_at: Time.current,
      enqueued_at: Time.current
    }.merge(attributes))
  end

  it "suspends rollout-gated schedules and restores a legacy-suspended preview schedule while the gate is off" do
    requested_at = 5.minutes.ago
    locked_at = 2.minutes.ago
    schedule = create_schedule(
      job_key: "reconcile_external_folder_sync_webhook_events",
      next_run_at: 1.minute.ago,
      run_requested_at: requested_at,
      locked_at:,
      locked_by: "existing-owner"
    )
    preview_schedule = create_schedule(
      job_key: "reconcile_docusaurus_preview_builds",
      enabled: false,
      enabled_before_reliability_v2_suspend: true
    )
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
    allow(RecurringJobRunnerJob).to receive(:set)

    described_class.perform_now

    expect(schedule.reload).to have_attributes(
      enabled: false,
      enabled_before_reliability_v2_suspend: true,
      run_requested_at: be_within(1.second).of(requested_at),
      locked_at: be_within(1.second).of(locked_at),
      locked_by: "existing-owner"
    )
    expect(preview_schedule.reload).to have_attributes(
      enabled: true,
      enabled_before_reliability_v2_suspend: nil
    )
    expect(RecurringJobSchedule.due).not_to include(schedule)
    expect(RecurringJobRunnerJob).not_to have_received(:set)
  end

  it "restores each v2 schedule to its pre-suspension enabled state when the gate is on" do
    originally_enabled = create_schedule(
      job_key: "retry_failed_webhook_deliveries",
      enabled: false,
      enabled_before_reliability_v2_suspend: true
    )
    originally_disabled = create_schedule(
      job_key: "recover_generated_file_events",
      enabled: false,
      enabled_before_reliability_v2_suspend: false
    )
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)

    described_class.perform_now

    expect(originally_enabled.reload).to have_attributes(
      enabled: true,
      enabled_before_reliability_v2_suspend: nil
    )
    expect(originally_disabled.reload).to have_attributes(
      enabled: false,
      enabled_before_reliability_v2_suspend: nil
    )
  end

  it "marks a stale enqueued run failed and releases only its own schedule lock" do
    schedule = create_schedule
    run = create_run(schedule, enqueued_at: 11.minutes.ago)
    schedule.update!(locked_at: 11.minutes.ago, locked_by: run.public_id)

    described_class.perform_now

    expect(run.reload).to have_attributes(
      status: "failed",
      error_message: RecurringJobRun::STALE_ENQUEUED_ERROR_MESSAGE
    )
    expect(run.finished_at).to be_present
    expect(schedule.reload).to have_attributes(locked_at: nil, locked_by: nil, last_status: "failed")
  end

  it "recovers only a stale running preview reconciliation whose run still owns the schedule lock" do
    generic_schedule = create_schedule
    generic_started_at = 2.hours.ago
    generic_run = create_run(generic_schedule, status: :running, started_at: generic_started_at)
    generic_schedule.update!(locked_at: generic_started_at, locked_by: generic_run.public_id, last_status: "running")

    preview_schedule = create_schedule(job_key: "reconcile_docusaurus_preview_builds")
    preview_started_at = 31.minutes.ago
    preview_run = create_run(preview_schedule, status: :running, started_at: preview_started_at)
    preview_schedule.update!(locked_at: preview_started_at, locked_by: preview_run.public_id, last_status: "running")

    described_class.perform_now

    expect(generic_run.reload).to have_attributes(
      status: "running",
      started_at: be_within(1.second).of(generic_started_at),
      finished_at: nil,
      error_message: nil
    )
    expect(generic_schedule.reload).to have_attributes(
      locked_at: be_within(1.second).of(generic_started_at),
      locked_by: generic_run.public_id,
      last_status: "running"
    )
    expect(preview_run.reload).to have_attributes(
      status: "failed",
      error_message: RecurringJobRun::STALE_RUNNING_ERROR_MESSAGE
    )
    expect(preview_run.finished_at).to be_present
    expect(preview_schedule.reload).to have_attributes(
      locked_at: nil,
      locked_by: nil,
      last_status: "failed"
    )
  end

  it "does not create an overlapping run while a non-stale enqueued run is active" do
    schedule = create_schedule(next_run_at: 1.minute.ago)
    active_run = create_run(schedule)
    allow(RecurringJobRunnerJob).to receive(:set)

    expect { described_class.perform_now }
      .not_to change(RecurringJobRun, :count)

    expect(active_run.reload).to be_enqueued
    expect(schedule.reload.next_run_at).to be > Time.current
    expect(RecurringJobRunnerJob).not_to have_received(:set)
  end

  it "persists the reservation and active job id before leaving it for the runner" do
    schedule = create_schedule(next_run_at: 1.minute.ago)
    configured_job = double("configured recurring job")
    active_job = double("active job", job_id: "runner-job-id")
    allow(RecurringJobRunnerJob).to receive(:set).with(queue: "default").and_return(configured_job)
    allow(configured_job).to receive(:perform_later).and_return(active_job)

    expect { described_class.perform_now }
      .to change(RecurringJobRun, :count).by(1)

    run = schedule.recurring_job_runs.last
    expect(run).to have_attributes(status: "enqueued", active_job_id: "runner-job-id")
    expect(schedule.reload).to have_attributes(locked_by: run.public_id, last_status: "enqueued")
  end

  it "enqueues protocol-v2 preview runs while the rollout gate is off" do
    schedule = create_schedule(
      job_key: "reconcile_docusaurus_preview_builds",
      next_run_at: 1.minute.ago
    )
    configured_job = double("configured recurring job")
    active_job = double("active job", job_id: "v2-runner-job-id")
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
    allow(RecurringJobRunnerJob).to receive(:set).with(queue: "default").and_return(configured_job)
    allow(configured_job).to receive(:perform_later).and_return(active_job)

    described_class.perform_now

    run = schedule.recurring_job_runs.last
    expect(configured_job).to have_received(:perform_later).with(
      run.id,
      RecurringJobDefinition::V2_RUNNER_PROTOCOL_VERSION
    )
    expect(run.reload.active_job_id).to eq("v2-runner-job-id")
  end

  it "marks the reservation failed and unlocks when queue insertion fails" do
    schedule = create_schedule(next_run_at: 1.minute.ago)
    configured_job = double("configured recurring job")
    allow(RecurringJobRunnerJob).to receive(:set).and_return(configured_job)
    allow(configured_job).to receive(:perform_later).and_return(nil)

    expect { described_class.perform_now }.to raise_error(RuntimeError)

    run = schedule.recurring_job_runs.last
    expect(run.reload).to be_failed
    expect(run.finished_at).to be_present
    expect(schedule.reload).to have_attributes(locked_at: nil, locked_by: nil, last_status: "failed")
  end

  it "does not recover v2 reservations or locks while the rollout gate is off" do
    schedule = create_schedule(
      job_key: "retry_failed_webhook_deliveries",
      job_class: "WebhookDeliveryAutoRetryJob"
    )
    run = create_run(schedule, enqueued_at: 11.minutes.ago)
    schedule.update!(locked_at: 11.minutes.ago, locked_by: run.public_id)
    orphaned_lock = create_schedule(
      job_key: "recover_generated_file_events",
      locked_at: 11.minutes.ago,
      locked_by: "missing-run"
    )
    original_run = run.attributes
    original_schedule = schedule.reload.attributes
    original_orphaned_lock = orphaned_lock.attributes
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    described_class.perform_now

    expect(run.reload.attributes).to eq(original_run)
    expect(schedule.reload).to have_attributes(
      enabled: false,
      enabled_before_reliability_v2_suspend: true,
      locked_at: original_schedule.fetch("locked_at"),
      locked_by: original_schedule.fetch("locked_by"),
      run_requested_at: original_schedule.fetch("run_requested_at")
    )
    expect(orphaned_lock.reload).to have_attributes(
      enabled: false,
      enabled_before_reliability_v2_suspend: true,
      locked_at: original_orphaned_lock.fetch("locked_at"),
      locked_by: original_orphaned_lock.fetch("locked_by"),
      run_requested_at: original_orphaned_lock.fetch("run_requested_at")
    )
  end

  it "does not dispatch an existing reliability v2 schedule while the rollout gate is off" do
    schedule = create_schedule(
      job_key: "reconcile_external_folder_sync_webhook_events",
      next_run_at: 1.minute.ago
    )
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
    allow(RecurringJobRunnerJob).to receive(:set)

    expect { described_class.perform_now }
      .not_to change(RecurringJobRun, :count)

    expect(schedule.reload.next_run_at).to be < Time.current
    expect(RecurringJobRunnerJob).not_to have_received(:set)
  end
end
