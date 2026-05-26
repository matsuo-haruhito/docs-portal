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
    expect(response.body).to include("適用対象は、会社向けかユーザー向けのどちらか一方を選びます。")
    expect(response.body).to include("会社全体に付与するときは「会社」を、個人に付与するときは「ユーザー」を指定してください。2つ同時には選択しません。")
    expect(response.body).to include("会社向けに付与する場合に選択")
    expect(response.body).to include("ユーザー向けに付与する場合に選択")
    expect(response.body).to include("会社単位かユーザー単位のどちらか一方を指定してください。")
    expect(response.body).not_to include("権限概要の表示設定")
    expect(response.body).not_to include("権限一覧の表示設定")
    expect(response.body).not_to include('data-rails-table-preferences-column-key="document"')
  end

  it "shows owner-scope guidance again when both company and user are submitted" do
    document = create(:document, title: "Permission Target")
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, email_address: "external@example.com")

    sign_in_as(admin_user)

    post admin_document_permissions_path, params: {
      document_permission: {
        document_id: document.id,
        company_id: company.id,
        user_id: external_user.id,
        access_level: "view"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("入力内容を確認してください。")
    expect(response.body).to include("company_id and user_id cannot both be set")
    expect(response.body).to include("適用対象は会社かユーザーのどちらか一方だけを指定してください。")
    expect(response.body).to include("会社向けに付与する場合に選択")
    expect(response.body).to include("ユーザー向けに付与する場合に選択")
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

  it "uses public_id-based action links on the index" do
    permission = create(:document_permission, access_level: :view)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_document_permission_path(permission.public_id))
    expect(response.body).to include(admin_document_permission_path(permission.public_id))
    expect(response.body).not_to include(edit_admin_document_permission_path(permission.id))
    expect(response.body).not_to include(admin_document_permission_path(permission.id))
  end

  it "finds the edit page by public_id" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    get edit_admin_document_permission_path(permission.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書権限編集")
  end

  it "rejects numeric ids on the edit page" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    get edit_admin_document_permission_path(permission.id)

    expect(response).to have_http_status(:not_found)
  end

  it "updates a document permission via public_id and keeps the index redirect" do
    permission = create(:document_permission, access_level: :view)

    sign_in_as(admin_user)

    patch admin_document_permission_path(permission.public_id), params: {
      document_permission: {
        document_id: permission.document_id,
        company_id: permission.company_id,
        user_id: permission.user_id,
        access_level: :download
      }
    }

    expect(response).to redirect_to(admin_document_permissions_path)
    expect(permission.reload.access_level).to eq("download")
  end

  it "rejects numeric ids on update" do
    permission = create(:document_permission, access_level: :view)

    sign_in_as(admin_user)

    patch admin_document_permission_path(permission.id), params: {
      document_permission: {
        document_id: permission.document_id,
        company_id: permission.company_id,
        user_id: permission.user_id,
        access_level: :download
      }
    }

    expect(response).to have_http_status(:not_found)
    expect(permission.reload.access_level).to eq("view")
  end

  it "destroys a document permission via public_id and keeps the index redirect" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    delete admin_document_permission_path(permission.public_id)

    expect(response).to redirect_to(admin_document_permissions_path)
    expect(DocumentPermission.exists?(permission.id)).to be(false)
  end

  it "rejects numeric ids on destroy" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    delete admin_document_permission_path(permission.id)

    expect(response).to have_http_status(:not_found)
    expect(DocumentPermission.exists?(permission.id)).to be(true)
  end
end