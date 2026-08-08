require "rails_helper"

RSpec.describe ExternalFolderSync::RunLease do
  it "allows the current pending owner to claim after the recovery deadline" do
    source = create(:external_folder_sync_source)
    reserved_at = 20.minutes.ago
    run = described_class.reserve!(source:, mode: :apply, at: reserved_at)
    claimed_at = Time.current

    expect(described_class.claim!(run, at: claimed_at)).to be(true)

    expect(run.reload).to be_running
    expect(source.reload.active_sync_run).to eq(run)
    expect(source.sync_lease_expires_at).to be > claimed_at
  end

  it "allows the current running owner to renew after the recovery deadline" do
    source = create(:external_folder_sync_source)
    reserved_at = 2.hours.ago
    run = described_class.reserve!(source:, mode: :apply, at: reserved_at)
    described_class.claim!(run, at: reserved_at + 1.minute)
    renewed_at = Time.current

    expect(described_class.heartbeat!(run, at: renewed_at)).to be(true)

    expect(run.reload.heartbeat_at).to be_within(1.second).of(renewed_at)
    expect(source.reload.sync_lease_expires_at).to be > renewed_at
  end

  it "allows the current running owner to complete after the recovery deadline" do
    source = create(:external_folder_sync_source)
    reserved_at = 2.hours.ago
    run = described_class.reserve!(source:, mode: :apply, at: reserved_at)
    described_class.claim!(run, at: reserved_at + 1.minute)
    completed_at = Time.current

    described_class.complete!(
      run,
      run_attributes: {status: :completed},
      source_attributes: {last_synced_at: completed_at},
      at: completed_at
    )

    expect(run.reload).to be_completed
    expect(source.reload).to have_attributes(
      active_sync_run_id: nil,
      sync_lease_expires_at: nil,
      last_synced_at: be_within(1.second).of(completed_at)
    )
  end

  it "fences an old owner after recovery has changed the source owner" do
    source = create(:external_folder_sync_source)
    run = described_class.reserve!(source:, mode: :apply)
    described_class.claim!(run)
    source.update_columns(sync_lease_expires_at: 1.minute.ago)

    expect(described_class.recover_stale_source!(source)).to be(true)
    replacement = described_class.reserve!(source:, mode: :apply)

    expect { described_class.heartbeat!(run) }
      .to raise_error(described_class::StaleClaimError)
    expect(source.reload.active_sync_run).to eq(replacement)
    expect(replacement.reload).to be_pending
  end

  it "does not adopt or recover a pointerless legacy owner by default" do
    source = create(:external_folder_sync_source)
    legacy_run = source.external_folder_sync_runs.create!(
      mode: :apply,
      status: :running,
      enqueued_at: 2.hours.ago,
      started_at: 2.hours.ago,
      heartbeat_at: 2.hours.ago
    )
    original_run = legacy_run.attributes

    expect { expect(described_class.reserve!(source:, mode: :apply)).to be_nil }
      .not_to change(ExternalFolderSyncRun, :count)

    expect(source.reload.active_sync_run).to be_nil
    expect(source.sync_lease_expires_at).to be_nil
    expect(legacy_run.reload.attributes).to eq(original_run)
  end
end
