require "rails_helper"

RSpec.describe "Admin document permission empty state clear links", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def section_for(heading)
    parsed_html.css("section.card").find do |section|
      section.at_css("h2")&.text&.squish == heading
    end
  end

  def section_clear_links(heading)
    section_for(heading).css("a[href]").select { |link| link.text.squish == "条件をクリア" }
  end

  it "shows clear links near both filtered empty states" do
    document = create(:document, title: "Existing Permission Guide")
    create(:document_permission, document:, company: create(:company, name: "Existing Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "missing")

    expect(response).to have_http_status(:ok)
    expect(section_clear_links("文書別の権限概要").map { _1["href"] }).to eq([admin_document_permissions_path])
    expect(section_clear_links("権限一覧").map { _1["href"] }).to eq([admin_document_permissions_path])
  end

  it "keeps initial empty states focused on registration guidance" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(section_clear_links("文書別の権限概要")).to be_empty
    expect(section_clear_links("権限一覧")).to be_empty
  end
end
