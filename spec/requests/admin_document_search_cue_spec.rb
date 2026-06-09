require "rails_helper"

RSpec.describe "Admin document search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def keyword_input
    parsed_html.at_css('input[name="q"]')
  end

  it "shows the keyword search target and length cue without hiding existing search handoff surfaces" do
    project = create(:project, code: "CUE-001", name: "Cue Project")
    create(:document, project:, title: "Cue Handbook", slug: "cue-handbook")

    sign_in_as(admin_user)

    get admin_documents_path, params: { q: "CUE-001" }

    expect(response).to have_http_status(:ok)
    expect(keyword_input).to be_present
    expect(keyword_input["maxlength"]).to eq(Admin::DocumentsController::DOCUMENT_SEARCH_QUERY_MAX_LENGTH.to_s)
    expect(keyword_input["placeholder"]).to eq("案件名・案件コード・文書名・URL識別子")
    expect(page_text).to include("案件名・案件コード・文書名・URL識別子の断片で検索できます。最大100文字。")
    expect(page_text).to include("検索結果: 1件", "有効な条件:", "キーワード: CUE-001")
    expect(page_text).to include("一括編集候補として開く", "文書マスタ一覧の表示設定")
  end
end
