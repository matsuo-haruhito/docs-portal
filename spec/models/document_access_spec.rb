require "rails_helper"

RSpec.describe DocumentAccess, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  after { travel_back }

  describe ".visible_in_portal_for" do
    it "matches the current external portal visibility predicate for publication windows" do
      travel_to Time.zone.local(2026, 1, 15, 12, 0, 0) do
        external_user = create(:user, :external)
        project = create(:project)
        create(:project_membership, project:, user: external_user)

        no_version_document = create(:document, project:, title: "No version", slug: "no-version")
        active_document = create(:document, project:, title: "Active version", slug: "active-version")
        draft_document = create(:document, project:, title: "Draft version", slug: "draft-version")
        future_document = create(:document, project:, title: "Future version", slug: "future-version")
        expired_document = create(:document, project:, title: "Expired version", slug: "expired-version")
        inaccessible_document = create(:document, project:, title: "No permission", slug: "no-permission")

        [no_version_document, active_document, draft_document, future_document, expired_document].each do |document|
          create(:document_permission, :company_scoped, document:, company: external_user.company)
        end

        create(:document_version, document: active_document, published_from: 1.day.ago, published_until: 1.day.from_now)
        create(:document_version, document: draft_document, status: :draft)
        create(:document_version, document: future_document, published_from: 1.day.from_now)
        create(:document_version, document: expired_document, published_until: 1.day.ago)
        create(:document_permission, :company_scoped, document: inaccessible_document, company: create(:company))

        expected_documents = Document.accessible_to(external_user).to_a.select do |document|
          document.visible_in_portal_for?(external_user)
        end

        expect(Document.visible_in_portal_for(external_user)).to match_array(expected_documents)
        expect(Document.visible_in_portal_for(external_user)).to include(no_version_document, active_document)
        expect(Document.visible_in_portal_for(external_user)).not_to include(
          draft_document,
          future_document,
          expired_document,
          inaccessible_document
        )
      end
    end
  end
end