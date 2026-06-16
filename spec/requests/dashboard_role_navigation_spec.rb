require "rails_helper"

RSpec.describe "Dashboard role navigation", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def nav_link_texts
    parsed_html.css("ul.nav-list a").map { |link| link.text.squish }
  end

  it "hides internal and admin dashboard links from external users" do
    sign_in_as(create(:user, :external))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("閲覧可能案件", "閲覧可能文書", "保留中の申請")
      expect(page_text).not_to include("保留中の確認依頼")
      expect(page_text).not_to include("社内向け導線")
      expect(page_text).not_to include("管理ダッシュボード")
    end
  end

  it "shows internal workflow links without the admin dashboard link to non-admin internal users" do
    sign_in_as(create(:user, :internal))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("保留中の確認依頼")
      expect(page_text).to include("社内向け導線")
      expect(page_text).to include("確認依頼一覧")
      expect(page_text).to include("外部送付履歴")
      expect(page_text).not_to include("管理ダッシュボード")
    end
  end

  it "shows the admin dashboard link to admin users" do
    sign_in_as(create(:user, :admin))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("保留中の確認依頼")
      expect(page_text).to include("社内向け導線")
      expect(page_text).to include("管理ダッシュボード")
    end
  end

  it "keeps the company master admin nav limited to company and user management" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(nav_link_texts).to eq(%w[会社 ユーザー])
      expect(nav_link_texts).not_to include("ダッシュボード")
      expect(nav_link_texts).not_to include("API仕様")
      expect(nav_link_texts).not_to include("モデルブラウザ")
      expect(nav_link_texts).not_to include("文書")
    end
  end
end
