require "rails_helper"

RSpec.describe ManualDocumentUploadReview do
  let(:actor) { create(:user, :internal) }
  let(:document) { create(:document) }

  def manual_upload_version(status: :draft, document: self.document, changelog_summary: nil)
    create(
      :document_version,
      document:,
      status:,
      source_commit_hash: described_class::MANUAL_UPLOAD_SOURCE,
      changelog_summary:
    )
  end

  describe "#approve!" do
    it "publishes a draft manual upload version and promotes it as the document latest version" do
      version = manual_upload_version(changelog_summary: "candidate imported")

      result = described_class.new(version:, actor:).approve!

      expect(result).to eq(version)
      expect(version.reload).to be_published
      expect(version.published_by_user).to eq(actor)
      expect(version.published_at).to be_present
      expect(version.changelog_summary).to include("candidate imported")
      expect(version.changelog_summary).to include("Approved manual upload at")
      expect(document.reload.latest_version).to eq(version)
    end
  end

  describe "#reject!" do
    it "archives a draft manual upload version and archives the document when no published version exists" do
      version = manual_upload_version(changelog_summary: "candidate imported")

      result = described_class.new(version:, actor:).reject!

      expect(result).to eq(document)
      expect(version.reload).to be_archived
      expect(version.changelog_summary).to include("candidate imported")
      expect(version.changelog_summary).to include("Rejected manual upload at")
      expect(document.reload).to be_archived
      expect(document.latest_version).to be_nil
    end

    it "keeps the document active and leaves the published latest version in place when one exists" do
      published_version = create(:document_version, document:, status: :published)
      document.update!(latest_version: published_version)
      version = manual_upload_version

      described_class.new(version:, actor:).reject!

      expect(version.reload).to be_archived
      expect(document.reload).not_to be_archived
      expect(document.latest_version).to eq(published_version)
    end
  end

  describe "review guards" do
    it "rejects non-manual upload versions" do
      version = create(:document_version, document:, status: :draft, source_commit_hash: "git-main")

      expect do
        described_class.new(version:, actor:).approve!
      end.to raise_error(ApplicationError::BadRequest, "手動アップロード候補版だけ操作できます。")
    end

    it "rejects non-draft manual upload versions" do
      version = manual_upload_version(status: :published)

      expect do
        described_class.new(version:, actor:).reject!
      end.to raise_error(ApplicationError::BadRequest, "draftの候補版だけ操作できます。")
    end
  end
end
