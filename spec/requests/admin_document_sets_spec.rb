require "rails_helper"

RSpec.describe "Admin document sets", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }
  let(:document_a) { create(:document, project:, title: "概要仕様", slug: "overview") }
  let(:document_b) { create(:document, project:, title: "社内メモ", slug: "internal-memo") }
  let!(:version_a1) { create(:document_version, document: document_a, version_label: "v1.0.0") }
  let!(:version_a2) { create(:document_version, document: document_a, version_label: "v2.0.0") }

  it "creates a document set with ordered items and a fixed version" do
    sign_in_as(admin)

    expect do
      post admin_document_sets_path, params: {
        document_set: {
          project_id: project.id,
          name: "初回提出セット",
          description: "first delivery",
          set_type: "delivery",
          visibility_policy: "restricted_external",
          sort_order: 3
        },
        document_set_items: {
          "0" => {
            selected: "1",
            document_id: document_a.id,
            document_version_id: version_a1.id,
            sort_order: 2,
            note: "固定版"
          },
          "1" => {
            selected: "1",
            document_id: document_b.id,
            document_version_id: "",
            sort_order: 5,
            note: ""
          }
        }
      }
    end.to change(DocumentSet, :count).by(1)

    expect(response).to redirect_to(admin_document_sets_path)

    document_set = DocumentSet.order(:id).last
    expect(document_set.document_set_items.ordered.map(&:document)).to eq([document_a, document_b])
    expect(document_set.document_set_items.ordered.first.document_version).to eq(version_a1)
    expect(document_set.document_set_items.ordered.second.document_version).to be_nil
  end
end
