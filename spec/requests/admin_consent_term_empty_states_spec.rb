require "rails_helper"

RSpec.describe "Admin consent term empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_consent_term!(attributes = {})
    ConsentTerm.create!({
      title: "Portal Consent",
      body: "利用規約に同意してください。",
      version_label: "v1",
      consent_scope: :project,
      requirement_timing: :first_view,
      active: true
    }.merge(attributes))
  end

  it "shows the initial empty state without filtered reset actions" do
    sign_in_as(admin_user)

    get admin_consent_terms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだ同意文面はありません。")
    expect(response.body).to include("上の「新規登録」でタイトル、版、種別、再同意方針を設定して最初の文面を保存してください。")
    expect(response.body).not_to include("条件に一致する同意文面はありません。")
    expect(parsed_html.at_css(".consent-term-filter-empty-state")).to be_nil
  end

  it "shows reset and state-review guidance for filtered empty results" do
    create_consent_term!(title: "Archived Consent", version_label: "v1", active: false)

    sign_in_as(admin_user)

    get admin_consent_terms_path, params: { active: "true" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する同意文面はありません。")
    expect(response.body).to include("タイトル・版ラベル、状態、種別、再同意方針の条件を見直すか、条件をリセットして一覧全体を確認してください。")
    expect(response.body).to include("状態を有効または無効に絞っている場合は、状態を「すべて」に戻すと利用中と無効化済みの両方を確認できます。")
    expect(response.body).to include("新しい版が必要な場合は、上の「新規登録」で既存版を上書きせず登録してください。")

    empty_state = parsed_html.at_css(".consent-term-filter-empty-state")
    expect(empty_state).to be_present
    clear_action = empty_state.at_css(%(p.actions a.button.secondary[href="#{admin_consent_terms_path}"]))
    expect(clear_action&.text&.squish).to eq("条件をリセット")
  end

  it "keeps the consent term filter parameter names unchanged" do
    sign_in_as(admin_user)

    get admin_consent_terms_path, params: {
      q: "portal",
      active: "true",
      consent_scope: "project",
      requirement_timing: "first_view"
    }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css('input[name="q"]')).to be_present
    expect(parsed_html.at_css('select[name="active"]')).to be_present
    expect(parsed_html.at_css('select[name="consent_scope"]')).to be_present
    expect(parsed_html.at_css('select[name="requirement_timing"]')).to be_present
  end
end
