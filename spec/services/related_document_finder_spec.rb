require "rails_helper"

RSpec.describe RelatedDocumentFinder do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }

  def create_document_with_source_path(title:, slug:, source_path:, document_kind: :markdown, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, document_kind:, visibility_policy:)
    version = create(:document_version, document:)
    version.assign_source_path_metadata!(source_path: source_path)
    version.save!
    document.update!(latest_version: version)
    document
  end

  it "returns explicit relations separately from inferred relations" do
    source = create_document_with_source_path(
      title: "README",
      slug: "readme",
      source_path: "作成資料/編集正本/README.md"
    )
    explicit_target = create_document_with_source_path(
      title: "先に読む資料",
      slug: "prerequisite",
      source_path: "作成資料/前提/概要.md"
    )
    inferred_target = create_document_with_source_path(
      title: "README PDF",
      slug: "readme-pdf",
      source_path: "作成資料/編集正本PDF化済/README.pdf",
      document_kind: :pdf
    )
    create(:document_relation, source_document: source, target_document: explicit_target, relation_type: :prerequisite)

    results = described_class.new(document: source, user: user).grouped_results

    expect(results[:explicit].map(&:document)).to eq([explicit_target])
    expect(results[:explicit].map(&:relation_type)).to eq(["prerequisite"])
    expect(results[:inferred].map(&:document)).to include(inferred_target)
    expect(results[:inferred].map(&:relation_type)).to include(:same_source_basename)
  end

  it "infers documents in the same source directory" do
    source = create_document_with_source_path(
      title: "設計書",
      slug: "design",
      source_path: "作成資料/編集正本/設計書.md"
    )
    same_directory = create_document_with_source_path(
      title: "補足資料",
      slug: "appendix",
      source_path: "作成資料/編集正本/補足資料.md"
    )

    results = described_class.new(document: source, user: user).inferred_relations

    expect(results.map(&:document)).to include(same_directory)
    expect(results.map(&:relation_type)).to include(:same_source_directory)
  end

  it "does not return explicit related documents the user cannot view" do
    company = create(:company)
    external_user = create(:user, :external, company: company)
    source = create_document_with_source_path(
      title: "公開資料",
      slug: "public-doc",
      source_path: "作成資料/編集正本/README.md"
    )
    visible = create_document_with_source_path(
      title: "公開関連",
      slug: "visible-related",
      source_path: "作成資料/編集正本/visible.md"
    )
    hidden = create_document_with_source_path(
      title: "社内関連",
      slug: "internal-related",
      source_path: "作成資料/編集正本/internal.md",
      visibility_policy: :internal_only
    )
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: source, company: company, access_level: :view)
    create(:document_permission, document: visible, company: company, access_level: :view)
    create(:document_relation, source_document: source, target_document: visible, relation_type: :related)
    create(:document_relation, source_document: source, target_document: hidden, relation_type: :appendix)

    results = described_class.new(document: source, user: external_user).explicit_relations

    expect(results.map(&:document)).to contain_exactly(visible)
  end

  it "does not return inferred documents the user cannot view" do
    company = create(:company)
    external_user = create(:user, :external, company: company)
    source = create_document_with_source_path(
      title: "公開資料",
      slug: "public-doc",
      source_path: "作成資料/編集正本/README.md"
    )
    hidden = create_document_with_source_path(
      title: "社内資料",
      slug: "internal-doc",
      source_path: "作成資料/編集正本/README.pdf",
      document_kind: :pdf,
      visibility_policy: :internal_only
    )
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: source, company: company, access_level: :view)

    results = described_class.new(document: source, user: external_user).inferred_relations

    expect(results.map(&:document)).not_to include(hidden)
  end
end
