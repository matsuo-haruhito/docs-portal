require "rails_helper"

RSpec.describe "Accessible document search cue", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Alpha Project", code: "ALPHA") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "shows the searchable fields and short-phrase guidance near the keyword input" do
    sign_in_as(user)

    get documents_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("文書名・案件名・本文・タグ・添付ファイル名・元パスの短い語句で検索できます。")

    keyword_input = parsed_html.at_css("input[name='q']")
    expect(keyword_input["placeholder"]).to eq("文書名・案件名など")
    expect(keyword_input["maxlength"]).to be_nil
  end
end
