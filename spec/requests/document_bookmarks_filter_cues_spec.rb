require "rails_helper"

RSpec.describe "Document bookmark filter cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  it "labels saved shortcut filters and keeps recent search params on that form" do
    sign_in_as(user)

    get document_bookmarks_path, params: { recent_q: "guide" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対象: お気に入り・後で読む")
    expect(response.body).to include("最近見た文書は下の検索で絞り込みます。")
    expect(response.body).to include("最近見た文書検索「guide」は、表示中の最大 20 件だけを絞り込んでいます。保存済みショートカットの条件は維持されます。お気に入り・後で読むには効きません。")

    saved_filter_form = page.css("section form").first
    recent_query_input = saved_filter_form.at_css('input[type="hidden"][name="recent_q"]')

    expect(recent_query_input).to be_present
    expect(recent_query_input["value"]).to eq("guide")
  end

  it "labels recent document search and keeps saved shortcut filters on that form" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { project_code: project.code, bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対象: 最近見た文書（表示中最大 20 件）")
    expect(response.body).to include("保存済みショートカットの条件はそのまま維持されます。")
    expect(response.body.scan("保存済み条件が適用中").size).to eq(2)
    expect(response.body).to include("この一覧は上の案件・検索語で絞り込んだお気に入りです。最近見た条件はここには効きません。")
    expect(response.body).to include("この一覧は上の案件・検索語で絞り込んだ後で読む文書です。最近見た条件はここには効きません。")
    expect(response.body).to include("保存済み条件は維持のみ")
    expect(response.body).to include("上の案件・保存済み検索は最近見た文書を絞り込みません。")

    recent_search_form = page.css("section form").last
    project_code_input = recent_search_form.at_css('input[type="hidden"][name="project_code"]')
    bookmark_query_input = recent_search_form.at_css('input[type="hidden"][name="bookmark_q"]')

    expect(project_code_input).to be_present
    expect(project_code_input["value"]).to eq(project.code)
    expect(bookmark_query_input).to be_present
    expect(bookmark_query_input["value"]).to eq("manual")
  end
end