require "rails_helper"

RSpec.describe RecurringJobDefinition do
  it "keeps reliability v2 definitions hidden while the rollout gate is off" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    expect(described_class.all.map(&:job_key)).not_to include(*described_class.v2_job_keys)
    expect(described_class.find("reconcile_external_folder_sync_webhook_events")).to be_nil
  end

  it "recognizes reliability v2 job keys without depending on gate state" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    expect(described_class.v2_job_key?("retry_failed_webhook_deliveries")).to be(true)
    expect(described_class.v2_job_key?("sync_git_import_sources")).to be(false)
  end

  it "publishes reliability v2 definitions after the rollout gate is enabled" do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)

    expect(described_class.all.map(&:job_key)).to include(*described_class.v2_job_keys)
    expect(described_class.find("reconcile_external_folder_sync_webhook_events")).to be_present
  end
end
