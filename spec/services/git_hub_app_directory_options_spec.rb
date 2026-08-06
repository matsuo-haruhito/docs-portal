require "rails_helper"

RSpec.describe GitHubAppDirectoryOptions do
  describe "#call" do
    it "returns directories when all params are present and API succeeds" do
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_return(%w[docs docs/guides lib src])

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        client: fake_client
      ).call

      expect(result.fallback?).to eq(false)
      expect(result.directories).to eq(%w[docs docs/guides lib src])
      expect(result.message).to be_nil
    end

    it "returns fallback when installation_id is blank" do
      result = described_class.new(
        installation_id: "",
        repository: "org/repo",
        branch: "main"
      ).call

      expect(result.fallback?).to eq(true)
      expect(result.directories).to eq([])
      expect(result.message).to include("installation ID")
    end

    it "returns fallback when repository is blank" do
      result = described_class.new(
        installation_id: "12345",
        repository: "",
        branch: "main"
      ).call

      expect(result.fallback?).to eq(true)
      expect(result.directories).to eq([])
      expect(result.message).to include("リポジトリ")
    end

    it "returns fallback when branch is blank" do
      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: ""
      ).call

      expect(result.fallback?).to eq(true)
      expect(result.directories).to eq([])
      expect(result.message).to include("ブランチ")
    end

    it "returns fallback when API returns empty directories" do
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_return([])

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        client: fake_client
      ).call

      expect(result.fallback?).to eq(true)
      expect(result.directories).to eq([])
      expect(result.message).to include("見つかりません")
    end

    it "returns fallback when API raises an error" do
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_raise(StandardError.new("network error"))

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        client: fake_client
      ).call

      expect(result.fallback?).to eq(true)
      expect(result.directories).to eq([])
      expect(result.message).to eq(described_class::FALLBACK_MESSAGE)
    end

    it "respects the limit parameter" do
      many_dirs = (1..60).map { |i| "dir_#{i}" }
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_return(many_dirs.first(3))

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        limit: 3,
        client: fake_client
      ).call

      expect(result.directories.length).to be <= 3
    end

    it "handles Japanese and space-containing paths" do
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_return(["docs/日本語フォルダ", "docs/my folder", "src"])

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        client: fake_client
      ).call

      expect(result.fallback?).to eq(false)
      expect(result.directories).to include("docs/日本語フォルダ", "docs/my folder")
    end

    it "handles root-level directory representation" do
      fake_client = instance_double(GitHubAppDirectoryOptions::Client)
      allow(fake_client).to receive(:directories).and_return(%w[docs src])

      result = described_class.new(
        installation_id: "12345",
        repository: "org/repo",
        branch: "main",
        client: fake_client
      ).call

      expect(result.fallback?).to eq(false)
      expect(result.directories).to eq(%w[docs src])
    end
  end
end
