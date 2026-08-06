require "rails_helper"

RSpec.describe GitHubAppBranchOptions do
  describe "#call" do
    it "returns branches when installation_id and repository are present" do
      fake_client = instance_double(described_class::Client)
      allow(fake_client).to receive(:branches).and_return(%w[main develop release/v2])

      result = described_class.new(installation_id: "12345", repository: "org/repo", client: fake_client).call

      expect(result.fallback?).to eq(false)
      expect(result.branches).to eq(%w[main develop release/v2])
    end

    it "returns fallback when installation_id is blank" do
      result = described_class.new(installation_id: "", repository: "org/repo").call
      expect(result.fallback?).to eq(true)
      expect(result.message).to include("installation ID")
    end

    it "returns fallback when repository is blank" do
      result = described_class.new(installation_id: "12345", repository: "").call
      expect(result.fallback?).to eq(true)
      expect(result.message).to include("リポジトリ")
    end

    it "returns fallback when API returns empty" do
      fake_client = instance_double(described_class::Client)
      allow(fake_client).to receive(:branches).and_return([])

      result = described_class.new(installation_id: "12345", repository: "org/repo", client: fake_client).call
      expect(result.fallback?).to eq(true)
    end

    it "returns fallback on API error" do
      fake_client = instance_double(described_class::Client)
      allow(fake_client).to receive(:branches).and_raise(StandardError.new("network"))

      result = described_class.new(installation_id: "12345", repository: "org/repo", client: fake_client).call
      expect(result.fallback?).to eq(true)
      expect(result.message).to eq(described_class::FALLBACK_MESSAGE)
    end
  end
end
