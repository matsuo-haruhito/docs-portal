require "rails_helper"

RSpec.describe RecurringJobDefinition do
  it "keeps only rollout-gated definitions hidden while the rollout gate is off" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    published_job_keys = described_class.all.map(&:job_key)

    expect(published_job_keys).not_to include(*described_class.rollout_gated_job_keys)
    expect(published_job_keys).to include("reconcile_docusaurus_preview_builds")
    expect(described_class.find("reconcile_external_folder_sync_webhook_events")).to be_nil
  end

  it "separates rollout gating from the runner protocol contract" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    expect(described_class.rollout_gated_job_key?("retry_failed_webhook_deliveries")).to be(true)
    expect(described_class.rollout_gated_job_key?("reconcile_docusaurus_preview_builds")).to be(false)
    expect(described_class.runner_protocol_v2_job_key?("reconcile_docusaurus_preview_builds")).to be(true)
    expect(described_class.runner_protocol_v2_job_key?("sync_git_import_sources")).to be(false)
  end

  it "publishes rollout-gated definitions after the rollout gate is enabled" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)

    expect(described_class.all.map(&:job_key)).to include(*described_class.rollout_gated_job_keys)
    expect(described_class.find("reconcile_external_folder_sync_webhook_events")).to be_present
  end
end
