require "rails_helper"

RSpec.describe "Admin access log empty state", type: :request do
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

  it "explains CSV and metadata output when active filters match no rows" do
    admin_user = create(:user, :internal)

    sign_in_as(admin_user)

    get admin_access_logs_path, params: { document_q: "does-not-match" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("CSV / metadata はこの条件で0件だったことや条件・scopeの確認に使えます。")
    expect(page_text).to include("監査ログ行データが存在することを示すものではありません。")
    expect(page_text).to include("絞り込み条件を見直すか、「条件をクリア」で最新200件を確認してください。")
    expect(page_text).to include("CSV条件metadata JSON")
    expect(page_text).to include("条件をクリア")
    expect(page_text).not_to include("監査ログ一覧の表示設定")
    expect(table_preference_column_keys).to be_empty
  end
end
