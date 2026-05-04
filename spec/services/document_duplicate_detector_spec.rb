require "rails_helper"

RSpec.describe DocumentDuplicateDetector do
  let(:project) { create(:project) }

  def create_document_with_version(title:, slug:, source_relative_path: nil, source_basename: nil)
    document = create(:document, project:, title:, slug:)
    version = create(
      :document_version,
      document:,
      source_relative_path:,
      source_basename:
    )
    document.update!(latest_version: version)
    document
  end

  it "detects documents with the same normalized title" do
    first = create_document_with_version(title: "操作説明書", slug: "manual-a")
    second = create_document_with_version(title: " 操作説明書 ", slug: "manual-b")
    create_document_with_version(title: "運用手順", slug: "operation")

    candidates = described_class.new(scope: Document.where(id: [first.id, second.id])).call

    expect(candidates.size).to eq(1)
    expect(candidates.first.reason).to eq(:same_title)
    expect(candidates.first.documents).to eq([first, second])
  end

  it "detects documents with the same latest source relative path" do
    first = create_document_with_version(title: "A", slug: "a", source_relative_path: "docs/manual.md")
    second = create_document_with_version(title: "B", slug: "b", source_relative_path: "docs\\manual.md")
    create_document_with_version(title: "C", slug: "c", source_relative_path: "docs/guide.md")

    candidates = described_class.new(scope: Document.where(id: [first.id, second.id])).call

    expect(candidates.map(&:reason)).to include(:same_source_relative_path)
    candidate = candidates.find { _1.reason == :same_source_relative_path }
    expect(candidate.value).to eq("docs/manual.md")
    expect(candidate.documents).to eq([first, second])
  end

  it "detects documents with the same latest source basename" do
    first = create_document_with_version(title: "A", slug: "a", source_basename: "README")
    second = create_document_with_version(title: "B", slug: "b", source_basename: "readme")

    candidates = described_class.new(scope: Document.where(id: [first.id, second.id])).call

    candidate = candidates.find { _1.reason == :same_source_basename }
    expect(candidate.documents).to eq([first, second])
  end

  it "ignores blank source metadata" do
    create_document_with_version(title: "A", slug: "a")
    create_document_with_version(title: "B", slug: "b")

    candidates = described_class.new.call

    expect(candidates.map(&:reason)).not_to include(:same_source_relative_path)
    expect(candidates.map(&:reason)).not_to include(:same_source_basename)
  end
end
