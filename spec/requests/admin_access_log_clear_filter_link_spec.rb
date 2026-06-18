require "rails_helper"
require "uri"

RSpec.describe "Admin access log clear filter link", type: :request do
  let(:admin_company) { create(:company, domain: "audit-clear.example.com", name: "Audit Clear Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_clear_links
    parsed_html.css(%(form[action="#{admin_access_logs_path}"] a[href="#{admin_access_logs_path}"])).select do |link|
      link.text.squish == "条件をクリア"
    end
  end

  def empty_state_clear_links
    parsed_html.css(%(.access-log-empty-state a[href="#{admin_access_logs_path}"])).select do |link|
      link.text.squish == "条件をクリア"
    end
  end

  def clear_link_queries(links)
    links.map { |link| URI.parse(link["href"]).query }
  end

  it "hides the clear link when no filters are active" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ監査ログはありません。")
    expect(filter_clear_links).to be_empty
    expect(empty_state_clear_links).to be_empty
  end

  it "shows the clear link when a filter is active" do
    sign_in_as(admin_user)

    get admin_access_logs_path, params: { document_q: "does-not-match" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("絞り込み条件を見直すか、「条件をクリア」で最新200件を確認してください。")
    expect(filter_clear_links.size).to eq(1)
    expect(empty_state_clear_links.size).to eq(1)
    expect(clear_link_queries(empty_state_clear_links)).to eq([nil])
  end
end
