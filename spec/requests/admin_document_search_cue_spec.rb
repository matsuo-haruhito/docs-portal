require "rails_helper"

RSpec.describe "Admin document search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def keyword_input
    parsed_html.at_css('input[name="q"]')
  end

  it "keeps the bounded search input, filter state, RTP table, and bulk handoff together" do
    project = create(:project, code: "CUE-001", name: "Cue Project")
    create(:document, project:, title: "Cue Handbook", slug: "cue-handbook")

    sign_in_as(admin_user)

    get admin_documents_path, params: { q: "CUE-001" }

    expect(response).to have_http_status(:ok)
    expect(keyword_input).to be_present
    expect(keyword_input["maxlength"]).to eq(Admin::DocumentsController::DOCUMENT_SEARCH_QUERY_MAX_LENGTH.to_s)
    expect(keyword_input["placeholder"]).to eq("案件名・案件コード・文書名・URL識別子")
    expect(keyword_input["class"]).to include("admin-filter-toolbar__search")
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("1件")
    expect(parsed_html.css(".admin-filter-chip").map { |node| node.text.squish }).to eq(["キーワード: CUE-001"])
    expect(parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_documents"]')).to be_present

    bulk_disclosure = parsed_html.css("details.filter-details").find do |details|
      details.at_css("summary")&.text&.squish == "一括操作"
    end
    expect(bulk_disclosure).to be_present
    expect(bulk_disclosure["open"]).to be_nil
    expect(bulk_disclosure.at_css('a[href*="source=admin_documents"]')).to be_present
  end
end
