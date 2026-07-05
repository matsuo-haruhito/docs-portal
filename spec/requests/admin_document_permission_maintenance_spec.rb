require "rails_helper"

RSpec.describe "Admin document permission maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }

  around do |example|
    previous_value = ENV["READ_ONLY_MAINTENANCE"]
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    example.run
  ensure
    ENV["READ_ONLY_MAINTENANCE"] = previous_value
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def maintenance_message
    "メンテナンス中のため文書権限の作成・更新・削除は停止しています。概要、一覧、検索、CSV は確認できます。"
  end

  it "does not create document permissions during maintenance mode" do
    document = create(:document, title: "Maintenance Permission Target")
    company = create(:company, name: "Maintenance Customer")

    sign_in_as(admin_user)

    expect do
      post admin_document_permissions_path, params: {
        document_permission: {
          document_id: document.id,
          company_id: company.id,
          access_level: "view"
        }
      }
    end.not_to change(DocumentPermission, :count)

    expect(response).to redirect_to(admin_document_permissions_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(maintenance_message)
    expect(page_text).to include("文書別の権限概要")
  end

  it "does not update document permissions during maintenance mode" do
    document = create(:document, title: "Existing Permission Target")
    company = create(:company, name: "Existing Company")
    user = create(:user, :external, email_address: "person@example.com")
    permission = create(:document_permission, document:, company:, access_level: :view)

    sign_in_as(admin_user)

    patch admin_document_permission_path(permission.public_id), params: {
      document_permission: {
        document_id: document.id,
        company_id: "",
        user_id: user.id,
        access_level: "download"
      }
    }

    expect(response).to redirect_to(admin_document_permissions_path)

    permission.reload
    expect(permission.access_level).to eq("view")
    expect(permission.company_id).to eq(company.id)
    expect(permission.user_id).to be_nil

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(maintenance_message)
  end

  it "does not destroy document permissions during maintenance mode" do
    permission = create(:document_permission)

    sign_in_as(admin_user)

    expect do
      delete admin_document_permission_path(permission.public_id)
    end.not_to change(DocumentPermission, :count)

    expect(response).to redirect_to(admin_document_permissions_path)
    expect(DocumentPermission.exists?(permission.id)).to be(true)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(maintenance_message)
  end

  it "keeps document permission index, csv, and search endpoints read-only during maintenance mode" do
    project = create(:project, code: "MAINT", name: "Maintenance Project")
    document = create(:document, project:, title: "Read Only Permission Guide", slug: "read-only-permission")
    company = create(:company, name: "Read Only Customer", domain: "readonly.example")
    create(:document_permission, document:, company:, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "Read Only")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Read Only Permission Guide")
    expect(page_text).to include("Read Only Customer")
    expect(page_text).to include("ダウンロード")

    get admin_document_permissions_path(format: :csv, q: "Read Only")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件コード,案件名,文書名,slug")
    expect(response.body).to include("MAINT,Maintenance Project,Read Only Permission Guide,read-only-permission")

    get document_search_admin_document_permissions_path(format: :json), params: { q: "read-only" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["options"]).to include(
      { "value" => document.id, "text" => "Read Only Permission Guide / Maintenance Project" }
    )
  end
end
