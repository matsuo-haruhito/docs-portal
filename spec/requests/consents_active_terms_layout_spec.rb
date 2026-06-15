require "rails_helper"

RSpec.describe "Consent active term layout", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def active_terms_section
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == "現在有効な注意事項" }
  end

  it "shows active terms as list items without nested cards" do
    create(:consent_term, title: "Project Terms", body: "Project terms body", version_label: "v1", consent_scope: :project)
    create(:consent_term, title: "Download Terms", body: "Download terms body", version_label: "v2", consent_scope: :download)

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)

    section = active_terms_section
    section_text = section.text.squish

    aggregate_failures do
      expect(section).to be_present
      expect(section.css(".card")).to be_empty
      expect(section.css(".consent-term-list .consent-term-item").size).to eq(2)
      expect(section_text).to include("Project Terms")
      expect(section_text).to include("Project terms body")
      expect(section_text).to include("Download Terms")
      expect(section_text).to include("Download terms body")
      expect(section_text).to include("種別:")
      expect(section_text).to include("版:")
    end
  end
end
