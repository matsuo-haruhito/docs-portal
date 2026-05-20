require "rails_helper"
require "fileutils"

RSpec.describe DocumentVersionQuality::MarkdownReferenceChecks do
  let(:check_class) { DocumentVersionQualityChecker::Check }
  let(:project) { create(:project, code: "QUALITY", name: "Quality Project") }
  let(:document) { create(:document, project:, title: "Guide", slug: "guide") }
  let(:version) do
    create(:document_version, document:, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/guide.mdx", snapshot_kind: "received_markdown")
      record.save!
    end
  end

  after do
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/quality-markdown-reference-checks"))
  end

  it "resolves links to mdx documents" do
    create_source_file!(version, "docs/guide.mdx", "[Next](next)\n")
    linked_document = create(:document, project:, title: "Next", slug: "next")
    create(:document_version, document: linked_document, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/next.mdx", snapshot_kind: "received_markdown")
      record.save!
    end

    checks = described_class.new(document_version: version, check_class:).call

    expect(checks).to be_empty
  end

  it "resolves links to mdx README-style documents" do
    create_source_file!(version, "docs/guide.mdx", "[Chapter](chapter)\n")
    linked_document = create(:document, project:, title: "Chapter", slug: "chapter")
    create(:document_version, document: linked_document, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/chapter/README.mdx", snapshot_kind: "received_markdown")
      record.save!
    end

    checks = described_class.new(document_version: version, check_class:).call

    expect(checks).to be_empty
  end

  private

  def create_source_file!(document_version, file_name, content)
    storage_key = "spec/quality-markdown-reference-checks/#{SecureRandom.hex(8)}.mdx"
    absolute_path = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    absolute_path.write(content)

    document_version.document_files.create!(
      file_name: file_name,
      content_type: "text/markdown",
      storage_key: storage_key,
      file_size: absolute_path.size,
      sort_order: document_version.document_files.count,
      scan_status: :scan_pending
    )
  end
end
