require "rails_helper"

RSpec.describe "Admin navigation", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def navbar_section_labels
    parsed_html.css("header .nav-dropdown__section-label").map { |node| node.text.squish }
  end

  def navbar_link_texts
    parsed_html.css("header .nav-dropdown__menu a").map { |node| node.text.squish }
  end

  def context_nav_link_texts
    parsed_html.css("nav.admin-context-nav a").map { |node| node.text.squish }
  end

  it "groups internal admin links in the shared navbar" do
    sign_in_as(create(:user, :internal))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(navbar_section_labels).to include(
      "管理ホーム",
      "マスタ管理",
      "文書管理",
      "運用",
      "診断",
      "仕様確認",
      "取込・同期",
      "通知連携"
    )
    expect(navbar_link_texts).to include(
      "管理画面 現在",
      "モデルブラウザ",
      "会社",
      "ユーザー",
      "文書",
      "文書カタログ",
      "文書権限",
      "ZIPインポート",
      "単体ファイルdry-run",
      "定期ジョブ",
      "生成ファイルイベント",
      "生成ファイル実行履歴",
      "Git取込履歴",
      "Microsoft Graph",
      "Webhook設定",
      "Webhook送信履歴"
    )
  end

  it "keeps company master admin context navigation limited to company and user management" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(context_nav_link_texts).to contain_exactly("会社", "ユーザー")
    expect(parsed_html.at_css("nav.admin-context-nav")["aria-label"]).to eq("会社・ユーザー管理")
    expect(navbar_section_labels).not_to include("管理ホーム", "マスタ管理", "文書管理", "運用", "通知連携")
  end
end
