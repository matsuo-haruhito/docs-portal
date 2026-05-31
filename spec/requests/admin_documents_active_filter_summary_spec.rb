require "rails_helper"

RSpec.describe "Admin documents active filter summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "shows active filter summaries near the result count" do
    create(:document, title: "Regular Document", retention_until: 1.month.ago, discard_candidate_at: nil)

    sign_in_as(admin_user)

    get admin_documents_path, params: {
      q: "Regular",
      archived: "active",
      retention: "due",
      discard: "missing"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果:")
    expect(page_text).to include("有効な条件:")
    expect(page_text).to include("キーワード: Regular")
    expect(page_text).to include("アーカイブ状態: 有効のみ")
    expect(page_text).to include("保管期限: 保管期限切れ")
    expect(page_text).to include("廃棄候補: 廃棄候補なし")
    expect(page_text).to include("条件をクリア")
  end
end