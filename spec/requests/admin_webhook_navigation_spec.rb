require "rails_helper"

RSpec.describe "Admin webhook navigation", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_texts_for(path)
    parsed_html.css(%(a[href="#{path}"])).map { |node| node.text.squish }
  end

  def active_dropdown_current_label
    parsed_html.at_css(".nav-dropdown__summary.is-active .nav-dropdown__current-label")&.text&.squish
  end

  it "links webhook settings and delivery history from the integration navigation" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(link_texts_for(admin_webhook_endpoints_path)).to include("Webhook設定")
    expect(link_texts_for(admin_webhook_deliveries_path)).to include("Webhook送信履歴 現在")
    expect(active_dropdown_current_label).to eq("Webhook送信履歴")
  end

  it "keeps webhook delivery history in the external integration admin section" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    dropdown = parsed_html.css("details.nav-dropdown").find do |node|
      node.at_css(".nav-dropdown__current-label")&.text&.squish == "Webhook送信履歴"
    end

    expect(dropdown).to be_present
    expect(dropdown.at_css("summary.nav-dropdown__summary")["class"]).to include("is-active")
    expect(dropdown.at_css(".nav-dropdown__section-label")&.text&.squish).to eq("仕様確認")
    expect(dropdown.text.squish).to include("通知連携", "Webhook設定", "Webhook送信履歴")
  end
end
