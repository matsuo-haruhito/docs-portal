require "rails_helper"

RSpec.describe "Admin document set search cue", type: :request do
  let(:admin) { create(:user, :admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def search_field
    parsed_html.at_css('form.document-set-filter-form input[name="q"]')
  end

  it "shows searchable fields and query limit next to the document set search input" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(search_field).to be_present
    expect(search_field["placeholder"]).to eq("案件名・案件コード・文書セット名")
    expect(search_field["maxlength"]).to eq(Admin::DocumentSetsController::DOCUMENT_SET_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include(
      "案件名・案件コード・文書セット名の断片で検索できます。最大#{Admin::DocumentSetsController::DOCUMENT_SET_QUERY_MAX_LENGTH}文字。"
    )
    expect(page_text).to include("CSV出力は現在の絞り込み条件に一致する文書セット集合")
  end
end
