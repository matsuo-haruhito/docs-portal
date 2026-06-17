require "rails_helper"

RSpec.describe "Consent section role cues", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT-CUE", name: "Consent Cue Project") }
  let(:document) { create(:document, project:, title: "Consent Cue Document", slug: "consent-cue-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def section_text(heading)
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == heading }&.text&.squish
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :download)
    document.update!(latest_version: version)
  end

  it "keeps active terms and consent history roles visually separate" do
    active_term = create(
      :consent_term,
      title: "Current Active Terms",
      body: "現在提示中の本文です。",
      version_label: "v-active",
      consent_scope: :project
    )
    history_term = create(
      :consent_term,
      title: "History Terms",
      body: "過去に同意した文面です。",
      version_label: "v-history",
      consent_scope: :download
    )
    create(:user_consent, user:, consent_term: history_term, target: project, consent_term_version_label: "v-history")

    sign_in_as(user)

    get consents_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      active_section = section_text("現在有効な注意事項")
      history_section = section_text("自分の同意履歴")

      expect(active_section).to include("役割: いま提示されている本文")
      expect(active_section).to include(active_term.title, "v-active", "現在提示中の本文です。")
      expect(history_section).to include("役割: 過去に同意した版の記録")
      expect(history_section).to include(history_term.title, "v-history", "案件 / Consent Cue Project")
    end
  end
end
