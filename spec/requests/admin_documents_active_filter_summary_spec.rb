require "rails_helper"

RSpec.describe "Admin documents active filter summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows active filter chips beside the result count" do
    create(:document, title: "Regular Document", retention_until: 1.month.ago, discard_candidate_at: nil)

    sign_in_as(admin_user)

    get admin_documents_path, params: {
      q: "Regular",
      archived: "active",
      retention: "due",
      discard: "missing"
    }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("1件")
    expect(parsed_html.css(".admin-filter-chip").map { |node| node.text.squish }).to contain_exactly(
      "キーワード: Regular",
      "アーカイブ状態: 有効のみ",
      "保管期限: 保管期限切れ",
      "廃棄候補: 廃棄候補なし"
    )
    expect(parsed_html.at_css('.admin-filter-toolbar__actions a[href="/admin/documents"]')&.text&.squish).to eq("条件をクリア")
  end
end
