require "rails_helper"

RSpec.describe DocumentDownloadsHelper, type: :helper do
  describe "#document_version_download_file" do
    let(:user) { create(:user, :internal) }
    let(:project) { create(:project, code: "DL") }
    let(:document) { create(:document, project:, title: "仕様書", slug: "spec") }

    before do
      current_user = user
      helper.define_singleton_method(:current_user) { current_user }
    end

    it "prefers the original source file over generated embeddable HTML" do
      version = create(
        :document_version,
        document:,
        source_file_name: "仕様書.md",
        source_extension: "md"
      )
      DocumentFile.create!(
        document_version: version,
        file_name: "index.html",
        content_type: "text/html",
        storage_key: "generated/index.html",
        file_size: 10,
        sort_order: 0
      )
      source_file = DocumentFile.create!(
        document_version: version,
        file_name: "仕様書.md",
        content_type: "text/markdown",
        storage_key: "sources/spec.md",
        file_size: 20,
        sort_order: 1
      )

      expect(helper.document_version_download_file(version)).to eq(source_file)
      expect(helper.document_file_icon_name(helper.document_version_download_file(version))).to eq("md")
    end

    it "falls back to the first downloadable file when source metadata is unavailable" do
      version = create(:document_version, document:)
      first_file = DocumentFile.create!(
        document_version: version,
        file_name: "manual.pdf",
        content_type: "application/pdf",
        storage_key: "files/manual.pdf",
        file_size: 10,
        sort_order: 0
      )

      expect(helper.document_version_download_file(version)).to eq(first_file)
    end
  end
end
