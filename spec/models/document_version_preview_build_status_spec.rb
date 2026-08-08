require "rails_helper"

RSpec.describe "DocumentVersion preview build status" do
  let(:version) { create(:document_version) }

  it "queues without consuming an HTTP build attempt" do
    expect(version.mark_preview_build_queued!).to be(true)

    expect(version).to have_attributes(
      preview_build_status: "preview_queued",
      preview_build_attempt_count: 0,
      preview_build_attempted_at: nil,
      preview_build_completed_at: nil
    )
    expect(version.preview_build_enqueued_at).to be_present
    expect(version.preview_build_error_message).to be_nil
  end

  it "claims a queued build once and records the persistent attempt" do
    version.mark_preview_build_queued!

    claim_token = version.claim_preview_build!

    expect(claim_token).to be_present
    expect(version).to have_attributes(
      preview_build_status: "preview_running",
      preview_build_attempt_count: 1,
      preview_build_claim_token: claim_token
    )
    expect(version.preview_build_attempted_at).to be_present
    expect(version.claim_preview_build!).to be_nil
    expect(version.reload.preview_build_attempt_count).to eq(1)
  end

  it "accepts completion only from the current claim" do
    version.mark_preview_build_queued!
    claim_token = version.claim_preview_build!

    expect(version.mark_preview_build_succeeded!(claim_token: "stale-token")).to be(false)
    expect(version.reload).to be_preview_running

    expect(version.mark_preview_build_succeeded!(claim_token:)).to be(true)
    expect(version.reload).to be_preview_succeeded
    expect(version.preview_build_claim_token).to be_nil
    expect(version.preview_build_completed_at).to be_present
  end

  it "schedules bounded backoff after a claimed failure" do
    now = Time.zone.parse("2026-08-06 12:00:00")
    version.mark_preview_build_queued!(at: now)
    claim_token = version.claim_preview_build!(at: now)

    expect(version.mark_preview_build_failed!("renderer failed", claim_token:, at: now)).to be(true)

    expect(version.reload).to be_preview_failed
    expect(version.preview_build_retry_at).to eq(now + 1.minute)
    expect(version.preview_build_claim_token).to be_nil
    expect(version.preview_build_completed_at).to eq(now)
  end

  it "abandons the build after the maximum number of claimed attempts" do
    version.update!(preview_build_attempt_count: DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS - 1)
    version.mark_preview_build_queued!
    claim_token = version.claim_preview_build!

    version.mark_preview_build_failed!("last failure", claim_token:)

    expect(version.reload).to be_preview_abandoned
    expect(version.preview_build_attempt_count).to eq(DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS)
    expect(version.preview_build_retry_at).to be_nil
    expect(version.mark_preview_build_queued!).to be(false)
  end
end
