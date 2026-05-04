require "rails_helper"

RSpec.describe DocumentVersion, type: :model do
  describe ".source_path_metadata_for!" do
    it "normalizes Windows separators and extracts path metadata" do
      metadata = described_class.source_path_metadata_for!("作成資料\\編集正本\\README.md")

      expect(metadata).to eq(
        source_relative_path: "作成資料/編集正本/README.md",
        source_directory: "作成資料/編集正本",
        source_file_name: "README.md",
        source_basename: "README",
        source_extension: "md"
      )
    end

    it "allows a file at the source root" do
      metadata = described_class.source_path_metadata_for!("README")

      expect(metadata).to include(
        source_relative_path: "README",
        source_directory: nil,
        source_file_name: "README",
        source_basename: "README",
        source_extension: nil
      )
    end

    it "rejects absolute paths" do
      expect {
        described_class.source_path_metadata_for!("/work/docs/README.md")
      }.to raise_error(ApplicationError::BadRequest)
    end

    it "rejects Windows absolute paths" do
      expect {
        described_class.source_path_metadata_for!("C:\\work\\docs\\README.md")
      }.to raise_error(ApplicationError::BadRequest)
    end

    it "rejects path traversal" do
      expect {
        described_class.source_path_metadata_for!("../secret.md")
      }.to raise_error(ApplicationError::BadRequest)
    end
  end

  describe "#assign_source_path_metadata!" do
    it "assigns normalized metadata and snapshot kind" do
      version = build(:document_version)

      version.assign_source_path_metadata!(
        source_path: "作成資料/提出済/設計書.pdf",
        snapshot_kind: "submitted"
      )

      expect(version.source_relative_path).to eq("作成資料/提出済/設計書.pdf")
      expect(version.source_directory).to eq("作成資料/提出済")
      expect(version.source_file_name).to eq("設計書.pdf")
      expect(version.source_basename).to eq("設計書")
      expect(version.source_extension).to eq("pdf")
      expect(version.snapshot_kind).to eq("submitted")
    end

    it "rejects unknown snapshot kinds" do
      version = build(:document_version)

      expect {
        version.assign_source_path_metadata!(source_path: "README.md", snapshot_kind: "unknown")
      }.to raise_error(ApplicationError::BadRequest)
    end
  end

  describe "publication window" do
    let(:now) { Time.zone.local(2026, 5, 4, 12, 0, 0) }
    let(:company) { create(:company) }
    let(:project) { create(:project) }
    let(:document) { create(:document, project:, visibility_policy: :restricted_external) }
    let(:version) { create(:document_version, document:, status: :published) }
    let(:external_user) { create(:user, :external, company:) }
    let(:internal_user) { create(:user, :internal) }

    before do
      create(:project_membership, project:, user: external_user)
      create(:document_permission, document:, company:, access_level: :view)
    end

    it "is active when no publication window is set" do
      expect(version).to be_within_publication_window
      expect(version.publication_window_state).to eq(:active)
    end

    it "is active within the publication window" do
      version.update!(published_from: now - 1.hour, published_until: now + 1.hour)

      expect(version.within_publication_window?(at: now)).to be(true)
      expect(version.publication_window_state(at: now)).to eq(:active)
    end

    it "is not started before the publication window" do
      version.update!(published_from: now + 1.hour)

      expect(version.within_publication_window?(at: now)).to be(false)
      expect(version.publication_window_state(at: now)).to eq(:not_started)
    end

    it "is expired after the publication window" do
      version.update!(published_until: now - 1.hour)

      expect(version.within_publication_window?(at: now)).to be(false)
      expect(version.publication_window_state(at: now)).to eq(:expired)
    end

    it "blocks external users outside the current publication window" do
      version.update!(published_from: Time.current + 1.day)

      expect(version.viewable_by?(external_user)).to be(false)
      expect(version.viewable_by?(internal_user)).to be(true)
    end

    it "validates publication window order" do
      version.published_from = now
      version.published_until = now - 1.hour

      expect(version).not_to be_valid
      expect(version.errors[:published_until]).to be_present
    end
  end
end
