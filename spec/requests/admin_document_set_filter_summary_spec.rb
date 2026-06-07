require "rails_helper"

RSpec.describe "Admin document set filter summary", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, code: "DOCSET", name: "Document Set Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
  end

  def links_named(label)
    parsed_html.css("a[href]").select { |node| node.text.squish == label }
  end

  it "keeps active filters, result count, clear link, and display settings copy together" do
    create(
      :document_set,
      project:,
      name: "送付用フィルター対象",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
    create(
      :document_set,
      project:,
      name: "社内共有セット",
      set_type: :requirement,
      visibility_policy: :internal_only,
      sort_order: 2
    )

    sign_in_as(admin)

    get admin_document_sets_path, params: {
      q: "送付用",
      set_type: "delivery",
      visibility_policy: "restricted_external"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("適用中: 検索: 送付用 種別: 送付用 公開範囲: 限定公開")
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).to include("表示設定は列の表示・幅を調整し、絞り込みは一覧に出す文書セットを切り替えます。")
    expect(page_text).to include("文書セット一覧の表示設定")
    expect(links_named("条件をクリア").map { _1["href"] }).to include(admin_document_sets_path)
    expect(listed_document_set_names).to eq(["送付用フィルター対象"])
  end

  it "explains filter and display settings roles when no filter is active" do
    create(:document_set, project:, name: "通常セット", sort_order: 1)

    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件名・案件コード・文書セット名、種別、公開範囲で一覧に出す文書セットを絞り込めます。表示設定は列の表示・幅を調整します。")
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).not_to include("適用中:")
    expect(listed_document_set_names).to eq(["通常セット"])
  end
end
