require "rails_helper"

RSpec.describe "Admin access log initial empty state copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def table_preference_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end
  end

  it "explains export and display-setting cues only in the initial empty state" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ監査ログはありません。")
    expect(page_text).to include("操作が記録されると、最新200件をここで確認できます。")
    expect(page_text).to include("監査ログが記録された後は、CSV export・metadata確認・表示設定で出力条件と一覧列を確認できます。")
    expect(page_text).not_to include("条件に一致する監査ログはありません。")
    expect(page_text).not_to include("条件をクリア")
    expect(table_preference_column_keys).to be_empty
  end

  it "keeps filtered empty state focused on clearing filters" do
    sign_in_as(admin_user)

    get admin_access_logs_path, params: { document_q: "does-not-match" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("絞り込み条件を見直すか、「条件をクリア」で最新200件を確認してください。")
    expect(page_text).to include("条件をクリア")
    expect(page_text).not_to include("まだ監査ログはありません。")
    expect(page_text).not_to include("監査ログが記録された後は、CSV export・metadata確認・表示設定で出力条件と一覧列を確認できます。")
    expect(table_preference_column_keys).to be_empty
  end
end
