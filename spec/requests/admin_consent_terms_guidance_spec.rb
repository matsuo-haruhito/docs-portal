require "rails_helper"

RSpec.describe "Admin consent term guidance", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows revision, status, and deletion guidance without changing table column keys" do
    sign_in_as(create(:user, :internal))
    ConsentTerm.create!(
      title: "利用規約",
      body: "Terms body",
      version_label: "v1",
      consent_scope: :project,
      requirement_timing: :first_view,
      active: true
    )
    ConsentTerm.create!(
      title: "秘密保持",
      body: "NDA body",
      version_label: "v0",
      consent_scope: :global,
      requirement_timing: :every_version_change,
      active: false
    )

    get admin_consent_terms_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("改訂するときは既存の文面を上書きせず、新しい版ラベルで登録してください。")
    expect(page_text).to include("状態の「利用中」は同意要求の候補に残る文面")
    expect(page_text).to include("無効化済み")
    expect(page_text).to include("履歴がある文面は削除せず、編集で無効化してください。")
    expect(response.body).to include("履歴がある場合は削除できません。")

    %w[title version_label consent_scope requirement_timing status actions].each do |column_key|
      expect(parsed_html.css(%([data-rails-table-preferences-column-key="#{column_key}"]))).not_to be_empty
    end
  end
end
