require "rails_helper"

RSpec.describe "Admin consent term filter summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows applied filters and result count when matching terms exist" do
    sign_in_as(admin_user)
    create_consent_term!(
      title: "案件利用規約",
      version_label: "2026-A",
      consent_scope: "project",
      requirement_timing: "first_view",
      active: true
    )
    create_consent_term!(
      title: "共有リンク利用規約",
      version_label: "2026-B",
      consent_scope: "shared_link",
      requirement_timing: "every_download",
      active: false
    )

    get admin_consent_terms_path(
      q: "利用規約",
      active: "true",
      consent_scope: "project",
      requirement_timing: "first_view"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する同意文面 1件中 1-1件を表示（検索: 利用規約 / 状態: 有効 / 種別: 案件 / 再同意方針: 初回表示時）")
    expect(reset_link_texts).to include("条件をリセット")
    expect(response.body).not_to include("条件に一致する同意文面はありません。")
    expect(parsed_html.at_css(%(th[data-rails-table-preferences-column-key="title"]))).to be_present
    expect(parsed_html.at_css(%(td[data-rails-table-preferences-column-key="consent_scope"])).text.squish).to include("案件")
  end

  it "keeps the filtered empty state and reset link when no terms match" do
    sign_in_as(admin_user)
    create_consent_term!(title: "案件利用規約", consent_scope: "project", active: true)

    get admin_consent_terms_path(q: "存在しない文面", active: "false")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する同意文面はありません。")
    expect(response.body).to include("タイトル・版ラベル、状態、種別、再同意方針の条件を見直すか、条件をリセットして一覧全体を確認してください。")
    expect(reset_link_texts).to include("条件をリセット")
    expect(response.body).not_to include("表示中: 0件")
  end

  def reset_link_texts
    parsed_html.css(%(a[href="#{admin_consent_terms_path}"])).map { |link| link.text.squish }
  end

  def create_consent_term!(attributes = {})
    defaults = {
      title: "同意文面",
      body: "本文",
      version_label: SecureRandom.hex(4),
      consent_scope: "project",
      requirement_timing: "first_view",
      active: true
    }

    ConsentTerm.create!(defaults.merge(attributes))
  end
end
