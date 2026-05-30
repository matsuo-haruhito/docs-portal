require "rails_helper"

RSpec.describe "Admin document permissions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def select_placeholder(field_name)
    parsed_html.at_css(%(select[name="#{field_name}"]))&.[]("placeholder")
  end

  def heading_texts
    parsed_html.css("h1, h2, h3").map { _1.text.squish }.reject(&:empty?)
  end

  def table_preference_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def node_ids
    parsed_html.css("[id]").map { _1["id"] }
  end

  it "shows empty-state guidance when no document permissions exist" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("文書別の権限概要", "適用対象", "権限一覧")
    expect(page_text.scan("まだ権限は登録されていません。").size).to eq(2)
    expect(page_text).to include("まだ権限は登録されていません。最初の 1 件を登録すると、文書ごとの権限数と閲覧/ダウンロード内訳をここで確認できます。")
    expect(page_text).to include("まずは上の「新規登録」で文書名と、会社またはユーザーのどちらかを指定して 1 件登録してください。")
    expect(page_text).to include("登録後は、会社別・ユーザー別の対象主体や権限内容をこの一覧で確認、編集できます。")
    expect(page_text).to include("会社向けかユーザー向けのどちらか一方を選びます。会社全体に付与するときは「会社」、個人に付与するときは「ユーザー」を指定してください。2つ同時には選択しません。")
    expect(select_placeholder("document_permission[company_id]")).to eq("会社向けに付与する場合に選択")
    expect(select_placeholder("document_permission[user_id]")).to eq("ユーザー向けに付与する場合に選択")
    expect(page_text).not_to include("会社単位かユーザー単位のどちらか一方を指定してください。")
    expect(page_text).not_to include("権限概要の表示設定")
    expect(page_text).not_to include("権限一覧の表示設定")
    expect(table_preference_column_keys).to be_empty
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
    expect(page_text).to include("入力内容を確認してください。")
    expect(page_text).to include("適用対象は会社かユーザーのどちらか一方だけを指定してください。")
    expect(page_text).to include("会社向けかユーザー向けのどちらか一方を選びます。会社全体に付与するときは「会社」、個人に付与するときは「ユーザー」を指定してください。2つ同時には選択しません。")
    expect(page_text).not_to include("company_id and user_id cannot both be set")
    expect(select_placeholder("document_permission[company_id]")).to eq("会社向けに付与する場合に選択")
    expect(select_placeholder("document_permission[user_id]")).to eq("ユーザー向けに付与する場合に選択")
  end

  it "shows document permission overview" do
    document = create(:document, title: "Permission Target", visibility_policy: :restricted_external)
    other_document = create(:document, title: "Another Target")
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, name: nil, email_address: "external@example.com")
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_permission, document:, user: external_user, access_level: :download)
    create(:document_permission, document: other_document, company:, access_level: :view)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("文書別の権限概要", "権限一覧")
    expect(page_text).to include("権限概要の表示設定")
    expect(page_text).to include("権限一覧の表示設定")
    expect(table_preference_column_keys).to include("document", "company", "access_level")
    expect(page_text).to include("Permission Target")
    expect(page_text).to include("限定公開")
    expect(page_text).to include("閲覧")
    expect(page_text).to include("ダウンロード")
    expect(page_text).to include("Customer Company")
    expect(page_text).to include("external@example.com")
    expect(action_targets).to include(
      project_document_path(document.project, document.slug),
      "#document-permissions-for-#{document.id}",
      "#document-permissions-for-#{other_document.id}"
    )
    expect(node_ids.count("document-permissions-for-#{document.id}")).to eq(1)
    expect(node_ids.count("document-permissions-for-#{other_document.id}")).to eq(1)
  end

  it "uses public_id-based action links on the index" do
    permission = create(:document_permission, access_level: :view)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(
      edit_admin_document_permission_path(permission.public_id),
      admin_document_permission_path(permission.public_id)
    )
    expect(action_targets).not_to include(
      edit_admin_document_permission_path(permission.id),
      admin_document_permission_path(permission.id)
    )
  end

  it "finds the edit page by public_id" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    get edit_admin_document_permission_path(permission.public_id)

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("文書権限編集")
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
