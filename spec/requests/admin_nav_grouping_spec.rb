require "rails_helper"

RSpec.describe "Admin navigation", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def admin_nav_section_labels
    parsed_html.css("ul.nav-list li.nav-section").map { |node| node.text.squish }
  end

  def admin_nav_link_texts
    parsed_html.css("ul.nav-list a").map { |node| node.text.squish }
  end

  it "groups internal admin links with lightweight area cues" do
    sign_in_as(create(:user, :internal))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(admin_nav_section_labels).to include(
      "運用",
      "基本マスタ",
      "文書・権限",
      "import / sync",
      "外部連携"
    )
    expect(admin_nav_link_texts).to include(
      "ダッシュボード",
      "モデルブラウザ",
      "会社",
      "ユーザー",
      "文書",
      "文書権限",
      "ZIPインポート",
      "Git同期履歴",
      "Microsoft Graph",
      "Webhook設定",
      "Webhook送信履歴"
    )
  end

  it "keeps company master admin navigation limited to company and user management" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(admin_nav_section_labels).to eq(["会社・ユーザー管理"])
    expect(admin_nav_link_texts).to contain_exactly("会社", "ユーザー")
    expect(admin_nav_link_texts).not_to include("モデルブラウザ", "文書", "Webhook設定")
  end
end
