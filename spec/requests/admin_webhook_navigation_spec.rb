require "rails_helper"

RSpec.describe "Admin webhook navigation", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_texts_for(path)
    parsed_html.css(%(a[href="#{path}"])).map { |node| node.text.squish }
  end

  it "links webhook settings and delivery history from the integration navigation" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(link_texts_for(admin_webhook_endpoints_path)).to include("Webhook設定")
    expect(link_texts_for(admin_webhook_deliveries_path)).to include("Webhook送信履歴")
    expect(parsed_html.text.squish).to include("連携メニュー 現在 Webhook送信履歴")
  end

  it "keeps webhook delivery history in the external integration admin section" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    section = parsed_html.at_xpath("//li[contains(@class, 'nav-section') and contains(normalize-space(.), '外部連携')]")
    expect(section).to be_present
    expect(section["aria-current"]).to eq("location")
    expect(section["aria-label"]).to eq("現在の領域: 外部連携")
  end
end
