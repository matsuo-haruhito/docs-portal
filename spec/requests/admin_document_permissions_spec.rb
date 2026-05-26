require "rails_helper"

RSpec.describe "Admin document permissions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows empty-state guidance when no document permissions exist" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書別の権限概要")
    expect(response.body).to include("権限一覧")
    expect(response.body.scan("まだ権限は登録されていません。").size).to eq(2)
    expect(response.body).to include("上の「新規登録」で文書名と、会社またはユーザーのどちらかを指定して保存すると、文書ごとの権限数と閲覧/ダウンロード内訳をここで見比べられます。")
    expect(response.body).to include("まずは上の「新規登録」で文書名と、会社またはユーザーのどちらかを指定して 1 件登録してください。")
    expect(response.body).to include("会社単位かユーザー単位のどちらかを指定してください。")
    expect(response.body).not_to include("権限概要の表示設定")
    expect(response.body).not_to include("権限一覧の表示設定")
    expect(response.body).not_to include('data-rails-table-preferences-column-key="document"')
  end

  it "shows document permission overview" do
    document = create(:document, title: "Permission Target", visibility_policy: :restricted_external)
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, name: nil, email_address: "external@example.com")
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_permission, document:, user: external_user, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書別の権限概要")
    expect(response.body).to include("権限概要の表示設定")
    expect(response.body).to include("権限一覧の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="document"')
    expect(response.body).to include('data-rails-table-preferences-column-key="company"')
    expect(response.body).to include('data-rails-table-preferences-column-key="access_level"')
    expect(response.body).to include("Permission Target")
    expect(response.body).to include("限定公開")
    expect(response.body).to include("閲覧")
    expect(response.body).to include("ダウンロード")
    expect(response.body).to include("Customer Company")
    expect(response.body).to include("external@example.com")
  end
end
