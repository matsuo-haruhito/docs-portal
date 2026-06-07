require "rails_helper"

RSpec.describe "Access request search copy", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  it "describes the actual searchable fields on the access request list" do
    sign_in_as(user)

    get access_requests_path

    expect(response).to have_http_status(:ok)
    query_field = Nokogiri::HTML.parse(response.body).at_css('input[name="q"]')
    expect(query_field["placeholder"]).to eq("対象名・案件コード・ID・ファイル名・理由で検索")
    expect(response.body).to include("案件コード・対象ID・ファイル名・理由で検索できます。")
  end
end
