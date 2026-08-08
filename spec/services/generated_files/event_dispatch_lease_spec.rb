require "rails_helper"

RSpec.describe GeneratedFiles::EventDispatchLease do
  let(:now) { Time.zone.parse("2026-08-06 12:00:00 UTC") }

  it "claims one source as a stable group with one owner token" do
    first = create(:generated_file_event, event_source: "manual", scheduled_at: 2.minutes.ago)
    second = create(:generated_file_event, event_source: "manual", scheduled_at: 1.minute.ago)

    claim = described_class.claim!([first, second], at: now)

    expect(claim.event_ids).to eq([first.id, second.id])
    expect(claim.event_source).to eq("manual")
    expect(claim.group_id).to be_present
    expect(claim.token).to be_present
    [first, second].each do |event|
      expect(event.reload).to have_attributes(
        status: "processing",
        dispatch_group_id: claim.group_id,
        dispatch_claim_token: claim.token,
        dispatch_claimed_at: now,
        dispatch_heartbeat_at: now
      )
    end
  end

  it "rotates a stale token and fences both late success and late failure from the old owner" do
    first = create(:generated_file_event, event_source: "manual", scheduled_at: 2.minutes.ago)
    second = create(:generated_file_event, event_source: "manual", scheduled_at: 1.minute.ago)
    old_claim = described_class.claim!([first, second], at: now - 20.minutes)

    replacement = described_class.recover_stale_groups!(limit: 100, at: now).sole

    expect(replacement.group_id).to eq(old_claim.group_id)
    expect(replacement.event_ids).to eq(old_claim.event_ids)
    expect(replacement.token).not_to eq(old_claim.token)
    expect(described_class.complete!(old_claim, at: now)).to be(false)
    expect(described_class.fail!(old_claim, error: "late failure", at: now)).to be(false)
    expect(first.reload).to be_processing
    expect(first.dispatch_claim_token).to eq(replacement.token)
    expect(second.reload.dispatch_claim_token).to eq(replacement.token)

    expect(described_class.complete!(replacement, at: now)).to be(true)
    expect([first.reload.status, second.reload.status]).to eq(%w[processed processed])
    expect([first.dispatch_group_id, second.dispatch_group_id]).to all(be_nil)
  end

  it "executes a commit block only for the current owner" do
    event = create(:generated_file_event, event_source: "manual", scheduled_at: 1.minute.ago)
    claim = described_class.claim!([event], at: now)
    committed = false

    result = described_class.with_ownership!(claim) do
      committed = true
      :committed
    end

    expect(result).to eq(:committed)
    expect(committed).to be(true)
  end

  it "raises before a stale owner can enter a commit block" do
    event = create(:generated_file_event, event_source: "manual", scheduled_at: 1.minute.ago)
    old_claim = described_class.claim!([event], at: now - 20.minutes)
    replacement = described_class.recover_stale_groups!(limit: 1, at: now).sole
    committed = false

    expect do
      described_class.with_ownership!(old_claim) { committed = true }
    end.to raise_error(described_class::StaleClaimError)

    expect(committed).to be(false)
    expect(event.reload.dispatch_claim_token).to eq(replacement.token)
  end

  it "recovers legacy events only when an explicit caller opts in" do
    event = create(:generated_file_event, event_source: "manual", scheduled_at: 1.hour.ago)
    event.update_columns(status: GeneratedFileEvent.statuses[:processing], updated_at: now - 20.minutes)

    expect(described_class.recover_stale_groups!(limit: 1, at: now)).to be_empty

    claim = described_class.recover_stale_groups!(limit: 1, at: now, recover_legacy: true).sole
    expect(claim.event_ids).to eq([event.id])
    expect(event.reload.dispatch_group_id).to eq(claim.group_id)
  end

  it "does not recover a group whose heartbeat is still fresh" do
    event = create(:generated_file_event, event_source: "manual", scheduled_at: 1.minute.ago)
    claim = described_class.claim!([event], at: now)

    expect(described_class.recover_stale_groups!(limit: 100, at: now + 14.minutes)).to be_empty
    expect(event.reload.dispatch_claim_token).to eq(claim.token)
  end
end
