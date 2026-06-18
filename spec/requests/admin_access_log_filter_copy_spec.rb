require "rails_helper"

RSpec.describe "Admin access log filter copy", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "uses operator-facing copy for AI context filters" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI出力モード")
    expect(page_text).to include("AI出力範囲")
    expect(page_text).to include("AI context export 用の追加条件")
    expect(page_text).to include("対象種別で AI context export を選んだ場合だけ、AI出力モード・範囲が有効です。")
    expect(page_text).to include("CSV export や有効な条件にも残りません。")
    expect(parsed_html.at_css('input[name="q"]')["placeholder"]).to eq("ZIP名・ファイル名・AI context export の記録・IP")
    expect(page_text).not_to include("AI context mode / scope は")
    expect(parsed_html.at_css('input[name="q"]')["placeholder"]).not_to include("raw")
  end
end
