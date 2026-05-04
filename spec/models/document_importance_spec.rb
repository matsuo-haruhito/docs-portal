require "rails_helper"

RSpec.describe Document, type: :model do
  describe "importance metadata" do
    let(:project) { create(:project) }

    it "defaults documents to normal importance" do
      document = create(:document, project:)

      expect(document.importance_level).to eq("normal")
      expect(document.recommended_sort_order).to eq(0)
    end

    it "orders documents by importance, recommended order, title, and id" do
      reference = create(:document, project:, title: "Reference", slug: "reference", importance_level: :reference, recommended_sort_order: 0)
      critical_later = create(:document, project:, title: "Critical B", slug: "critical-b", importance_level: :critical, recommended_sort_order: 2)
      important = create(:document, project:, title: "Important", slug: "important", importance_level: :important, recommended_sort_order: 1)
      critical_first = create(:document, project:, title: "Critical A", slug: "critical-a", importance_level: :critical, recommended_sort_order: 1)

      expect(described_class.where(id: [reference, critical_later, important, critical_first]).recommended_first).to eq([
        critical_first,
        critical_later,
        important,
        reference
      ])
    end

    it "returns only critical and important documents from important_first" do
      critical = create(:document, project:, title: "Critical", slug: "critical", importance_level: :critical)
      important = create(:document, project:, title: "Important", slug: "important", importance_level: :important)
      create(:document, project:, title: "Normal", slug: "normal", importance_level: :normal)

      expect(described_class.where(project:).important_first).to eq([critical, important])
    end

    it "does not allow negative recommended sort order" do
      document = build(:document, project:, recommended_sort_order: -1)

      expect(document).not_to be_valid
      expect(document.errors[:recommended_sort_order]).to be_present
    end
  end
end
