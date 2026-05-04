require "rails_helper"

RSpec.describe DocumentFile, type: :model do
  let(:version) { create(:document_version) }

  def build_file(attributes = {})
    described_class.new(
      {
        document_version: version,
        file_name: "manual.pdf",
        content_type: "application/pdf",
        storage_key: "spec/manual.pdf",
        file_size: 12,
        sort_order: 0
      }.merge(attributes)
    )
  end

  it "allows non-negative file size and sort order" do
    file = build_file(file_size: 0, sort_order: 0)

    expect(file).to be_valid
  end

  it "does not allow a negative file size" do
    file = build_file(file_size: -1)

    expect(file).not_to be_valid
    expect(file.errors[:file_size]).to be_present
  end

  it "does not allow a negative sort order" do
    file = build_file(sort_order: -1)

    expect(file).not_to be_valid
    expect(file.errors[:sort_order]).to be_present
  end

  describe "scan status delivery gate" do
    let(:external_user) { build(:user, :external) }
    let(:internal_user) { build(:user, :internal) }

    it "blocks external delivery while scan is pending but allows internal operational access" do
      file = build_file(scan_status: :scan_pending)

      expect(file).to be_blocked_by_scan
      expect(file.deliverable_after_scan?(external_user)).to be(false)
      expect(file.deliverable_after_scan?(internal_user)).to be(true)
    end

    it "allows external delivery after the scan is clean" do
      file = build_file(scan_status: :scan_clean)

      expect(file).not_to be_blocked_by_scan
      expect(file.deliverable_after_scan?(external_user)).to be(true)
    end

    it "blocks external delivery when the scan detects danger" do
      file = build_file(scan_status: :scan_infected)

      expect(file).to be_blocked_by_scan
      expect(file.deliverable_after_scan?(external_user)).to be(false)
    end
  end

  describe "downloadable_by?" do
    let(:company) { create(:company) }
    let(:project) { create(:project) }
    let(:document) { create(:document, project:, visibility_policy: :restricted_external) }
    let(:version) { create(:document_version, document:, status: :published) }
    let(:external_user) { create(:user, :external, company:) }
    let(:internal_user) { create(:user, :internal) }

    it "allows internal users regardless of scan status" do
      file = create(:document_file, document_version: version, scan_status: :scan_pending)

      expect(file.downloadable_by?(internal_user)).to be(true)
    end

    it "blocks external users until the file is clean" do
      create(:document_permission, document:, company:, access_level: :download)
      file = create(:document_file, document_version: version, scan_status: :scan_pending)

      expect(file.downloadable_by?(external_user)).to be(false)

      file.scan_clean!

      expect(file.downloadable_by?(external_user)).to be(true)
    end
  end
end
