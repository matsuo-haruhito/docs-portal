require "rails_helper"

RSpec.describe "Admin webhook delivery search preview", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:webhook_endpoint) { create(:webhook_endpoint, name: "Preview Endpoint") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def error_cells
    parsed_html.css(%(td[data-rails-table-preferences-column-key="error_message"]))
  end

  def action_hrefs
    parsed_html.css(%(td[data-rails-table-preferences-column-key="actions"] a[href])).map { _1["href"] }
  end

  it "shows masked error previews while preserving the detail route from the search list" do
    sign_in_as(admin_user)
    delivery = create(
      :webhook_delivery,
      webhook_endpoint:,
      status: :failed,
      response_status: 500,
      error_message: "Authorization: Bearer raw-secret-token\ntoken=abc123 failed at C:/Users/alice/customer/docs.yml"
    )

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Webhook送信履歴検索")
    expect(page_text).to include("表示範囲: 1件中1件を新しい順で表示しています。")
    expect(page_text).to include("Authorization: [masked]")
    expect(page_text).to include("token=[masked]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).not_to include("raw-secret-token")
    expect(page_text).not_to include("abc123")
    expect(page_text).not_to include("C:/Users/alice/customer/docs.yml")
    expect(error_cells.map { _1.text.squish }).to include("Authorization: [masked] token=[masked] failed at [path hidden]")
    expect(action_hrefs).to include(admin_webhook_delivery_path(delivery.public_id, status: "failed", return_context: "deliveries_index"))
  end

  it "keeps the error column key and blank error display stable" do
    sign_in_as(admin_user)
    create(:webhook_delivery, webhook_endpoint:, status: :failed, error_message: nil)

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css(%([data-rails-table-preferences-column-key="error_message"]))).to be_present
    expect(error_cells.map { _1.text.squish }).to include("-")
  end
end
