require "rails_helper"

RSpec.describe GeneratedFiles::OutputWriters::Filesystem do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "promotes staged artifacts while the event claim is current" do
    event = create(:generated_file_event, scheduled_at: 1.minute.ago)
    claim = GeneratedFiles::EventDispatchLease.claim!([event])
    artifact = GeneratedFiles::Artifact.new(
      path: "generated/current.md",
      content: "current owner",
      content_type: "text/markdown"
    )

    result = described_class.new(root: @root, dispatch_claim: claim).write([artifact])

    expect(result).to eq(["generated/current.md"])
    expect(@root.join("generated/current.md").read).to eq("current owner")
  end

  it "does not promote staged artifacts after the event claim is replaced" do
    event = create(:generated_file_event, scheduled_at: 1.minute.ago)
    old_claim = GeneratedFiles::EventDispatchLease.claim!([event], at: 20.minutes.ago)
    replacement = GeneratedFiles::EventDispatchLease.recover_stale_groups!(limit: 1).sole
    artifact = GeneratedFiles::Artifact.new(
      path: "generated/stale.md",
      content: "stale owner",
      content_type: "text/markdown"
    )

    expect do
      described_class.new(root: @root, dispatch_claim: old_claim).write([artifact])
    end.to raise_error(GeneratedFiles::EventDispatchLease::StaleClaimError)

    expect(event.reload.dispatch_claim_token).to eq(replacement.token)
    expect(@root.join("generated/stale.md")).not_to exist
  end
end
