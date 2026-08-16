require "rails_helper"

RSpec.describe "Admin webhook delivery date range cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows visible day-boundary cues near the created date filters" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日は開始日の00:00から終了日の23:59までを含みます。")
  end

  it "keeps the static day-boundary cues when an invalid date warning is shown" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path(created_from: "not-a-date")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日は開始日の00:00から終了日の23:59までを含みます。")
    expect(page_text).to include("作成日Fromの値が日付として解釈できないため、この条件は適用していません。")
  end
end
