require "rails_helper"

RSpec.describe DocumentRelation, type: :model do
  it "is valid between different documents" do
    source = create(:document)
    target = create(:document, project: source.project)

    relation = build(:document_relation, source_document: source, target_document: target)

    expect(relation).to be_valid
  end

  it "rejects self relations" do
    document = create(:document)

    relation = build(:document_relation, source_document: document, target_document: document)

    expect(relation).not_to be_valid
    expect(relation.errors[:target_document]).to include("must be different from source document")
  end

  it "rejects duplicate relation types for the same pair" do
    source = create(:document)
    target = create(:document, project: source.project)
    create(:document_relation, source_document: source, target_document: target, relation_type: :related)

    duplicate = build(:document_relation, source_document: source, target_document: target, relation_type: :related)

    expect(duplicate).not_to be_valid
  end
end
