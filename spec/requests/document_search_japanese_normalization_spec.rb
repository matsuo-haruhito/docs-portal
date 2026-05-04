require "rails_helper"
require "securerandom"

RSpec.describe "Document search Japanese normalization", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "JPN#{SecureRandom.hex(3)}", name: "Japanese Search Project") }

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  it "matches half-width kana document keywords with full-width kana queries" do
    document = create(:document, project:, title: "操作説明", slug: "operation-manual")
    create(:document_version, document:)
    DocumentKeyword.create!(document:, keyword: "ﾏﾆｭｱﾙ")

    sign_in_as(user)

    get project_documents_path(project, q: "マニュアル")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("操作説明")
  end
end
