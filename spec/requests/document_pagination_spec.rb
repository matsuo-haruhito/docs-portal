require "rails_helper"
require "securerandom"

RSpec.describe "Document pagination", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PG#{SecureRandom.hex(4)}", name: "Paging Project") }

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  it "paginates document index while preserving search conditions" do
    25.times do |index|
      document = create(
        :document,
        project:,
        title: format("Paging Document %02d", index),
        slug: format("paging-doc-%02d", index)
      )
      create(:document_version, document:, search_body_text: "paging-keyword")
    end

    sign_in_as(user)

    get project_documents_path(project, q: "paging-keyword")

    expect(response).to have_http_status(:ok)
    expect(result_titles.size).to eq(20)
    expect(response.body).to include("25")
    expect(response.body).to include("ページ 1 / 2")
    expect(response.body).to include("q=paging-keyword")
    expect(response.body).to include("page=2")

    get project_documents_path(project, q: "paging-keyword", page: 2)

    expect(response).to have_http_status(:ok)
    expect(result_titles.size).to eq(5)
    expect(response.body).to include("ページ 2 / 2")
  end

  it "normalizes invalid page values to the first page" do
    21.times do |index|
      create(
        :document,
        project:,
        title: format("Invalid Page Document %02d", index),
        slug: format("invalid-page-doc-%02d", index)
      )
    end

    sign_in_as(user)

    get project_documents_path(project, page: "not-a-number")

    expect(response).to have_http_status(:ok)
    expect(result_titles.size).to eq(20)
    expect(response.body).to include("ページ 1 / 2")

    get project_documents_path(project, page: 0)

    expect(response).to have_http_status(:ok)
    expect(result_titles.size).to eq(20)
    expect(response.body).to include("ページ 1 / 2")
  end
end
