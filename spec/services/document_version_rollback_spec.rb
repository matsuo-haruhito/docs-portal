require "rails_helper"

RSpec.describe DocumentVersionRollback do
  let(:actor) { create(:user, :internal) }
  let(:document) { create(:document) }

  def manual_upload_version(status: :published, document: self.document, created_at: nil, changelog_summary: nil)
    create(
      :document_version,
      document:,
      status:,
      source_commit_hash: described_class::MANUAL_UPLOAD_SOURCE,
      created_at: created_at || Time.current,
      changelog_summary:
    )
  end

  describe "#call" do
    it "archives the latest manual upload version and restores the previous published version" do
      older_version = create(:document_version, document:, status: :published, created_at: 3.days.ago)
      newer_previous_version = create(:document_version, document:, status: :published, created_at: 1.day.ago)
      rolled_back_version = manual_upload_version(created_at: Time.current, changelog_summary: "manual candidate")
      document.update!(latest_version: rolled_back_version)

      result = described_class.new(version: rolled_back_version, actor:).call

      expect(result).to eq(newer_previous_version)
      expect(rolled_back_version.reload).to be_archived
      expect(rolled_back_version.changelog_summary).to include("manual candidate")
      expect(rolled_back_version.changelog_summary).to include("Rolled back manual upload at")
      expect(document.reload.latest_version).to eq(newer_previous_version)
      expect(document).not_to be_archived
      expect(older_version.reload).to be_published
    end

    it "archives the document when there is no previous published version" do
      rolled_back_version = manual_upload_version(changelog_summary: "manual candidate")
      document.update!(latest_version: rolled_back_version)

      result = described_class.new(version: rolled_back_version, actor:).call

      expect(result).to be_nil
      expect(rolled_back_version.reload).to be_archived
      expect(rolled_back_version.changelog_summary).to include("Rolled back manual upload at")
      expect(document.reload.latest_version).to be_nil
      expect(document).to be_archived
    end
  end

  describe "rollback guards" do
    it "rejects a manual upload version that is not the latest version" do
      previous_version = manual_upload_version(created_at: 2.days.ago)
      latest_version = create(:document_version, document:, status: :published, created_at: 1.day.ago)
      document.update!(latest_version: latest_version)

      expect do
        described_class.new(version: previous_version, actor:).call
      end.to raise_error(ApplicationError::BadRequest, "最新の版だけ取り消せます。")
    end

    it "rejects a latest version that is not a manual upload version" do
      version = create(:document_version, document:, status: :published, source_commit_hash: "git-main")
      document.update!(latest_version: version)

      expect do
        described_class.new(version:, actor:).call
      end.to raise_error(ApplicationError::BadRequest, "手動アップロード版だけ取り消せます。")
    end
  end
end
