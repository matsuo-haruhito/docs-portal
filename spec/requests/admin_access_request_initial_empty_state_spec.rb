require "rails_helper"

RSpec.describe "Admin access request initial empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_texts
    parsed_html.css("a[href]").map { _1.text.squish }
  end

  it "explains the initial empty state without showing filtered-empty actions" do
    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請はありません。")
    expect(page_text).to include("利用者からアクセス申請が届くと、承認待ち・承認済み・却下の履歴がここに表示されます。")
    expect(page_text).not_to include("条件に一致する申請はありません。")
    expect(link_texts).not_to include("すべての申請を見る")
  end

  it "keeps filtered empty state separate from the initial empty guidance" do
    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する申請はありません。")
    expect(page_text).to include("状態: 承認待ち")
    expect(link_texts).to include("すべての申請を見る")
    expect(page_text).not_to include("利用者からアクセス申請が届くと、承認待ち・承認済み・却下の履歴がここに表示されます。")
  end
end
