require "rails_helper"

RSpec.describe "Admin document permission access level guidance", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "explains view and download access on the permission form" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css('select[name="document_permission[access_level]"]')).to be_present
    expect(page_text).to include("閲覧はportal上で文書を確認する権限です。")
    expect(page_text).to include("ダウンロードは閲覧に加えて添付・ファイル取得を許可するため、必要な場合だけ選択してください。")
    expect(page_text).to include("会社全体に付与するか、特定ユーザー1名に付与するかを選びます。")
  end
end
