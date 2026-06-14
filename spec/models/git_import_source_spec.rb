require "rails_helper"

RSpec.describe GitImportSource, type: :model do
  describe "sync marker reset" do
    it "clears synced metadata when import scope changes" do
      source = create(:git_import_source, last_synced_commit_sha: "abc123", last_synced_at: Time.current)

      source.update!(source_path: "作成資料")

      expect(source.last_synced_commit_sha).to be_nil
      expect(source.last_synced_at).to be_nil
    end

    it "keeps synced metadata when import scope does not change" do
      synced_at = Time.current
      source = create(:git_import_source, last_synced_commit_sha: "abc123", last_synced_at: synced_at)

      source.update!(enabled: false)

      expect(source.last_synced_commit_sha).to eq("abc123")
      expect(source.last_synced_at.to_i).to eq(synced_at.to_i)
    end
  end
end
