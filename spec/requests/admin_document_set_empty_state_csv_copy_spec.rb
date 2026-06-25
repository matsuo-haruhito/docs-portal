require "rails_helper"

RSpec.describe "Admin document set empty state CSV copy", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "CSV Copy Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filtered_empty_state_text
    parsed_html.at_css(".document-set-filter-empty-state")&.text&.squish
  end

  it "explains that CSV output follows the active filters when filtered results are empty" do
    create(
      :document_set,
      project:,
      name: "Delivery only set",
      set_type: :delivery,
      visibility_policy: :restricted_external
    )

    sign_in_as(admin)

    get admin_document_sets_path, params: { set_type: "design", visibility_policy: "public_with_login" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(filtered_empty_state_text).to include("条件に一致する文書セットはありません。")
    expect(filtered_empty_state_text).to include("CSV出力も現在の絞り込み条件に従います。このまま出力すると0件の結果になります。")
    expect(filtered_empty_state_text).to include("条件をクリア")
  end

  it "keeps the CSV empty-state explanation out of the unfiltered empty state" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ文書セットは登録されていません。")
    expect(page_text).not_to include("CSV出力も現在の絞り込み条件に従います。")
  end
end
