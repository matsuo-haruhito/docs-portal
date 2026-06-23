require "rails_helper"

RSpec.describe "Admin document permission table preferences", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def table_preference_surfaces(table_key)
    parsed_html.css(%([data-rails-table-preferences-table-key-value="#{table_key}"]))
  end

  def table_preference_table(table_key)
    parsed_html.at_css(%(table[data-rails-table-preferences-table-key-value="#{table_key}"]))
  end

  def table_preference_columns_for(surface)
    JSON.parse(surface["data-rails-table-preferences-columns-value"])
  end

  def table_preference_settings_for(surface)
    JSON.parse(surface["data-rails-table-preferences-settings-value"])
  end

  def header_column_keys(table_key)
    table_preference_table(table_key).css("thead th[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  it "keeps overview and detail table preference columns distinct" do
    document = create(:document, title: "Permission Target", visibility_policy: :restricted_external)
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, email_address: "external@example.com")
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_permission, document:, user: external_user, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(table_preference_surfaces("admin_document_permission_overview").size).to eq(2)
    expect(table_preference_surfaces("admin_document_permissions").size).to eq(2)

    overview_keys = table_preference_columns_for(table_preference_table("admin_document_permission_overview")).map { _1["key"] }
    permission_keys = table_preference_columns_for(table_preference_table("admin_document_permissions")).map { _1["key"] }

    expect(overview_keys).to eq(%w[
      document project visibility_policy company_permissions user_permissions view_allowed download_allowed
    ])
    expect(permission_keys).to eq(%w[
      document company user access_level actions
    ])
    expect(header_column_keys("admin_document_permission_overview")).to eq(overview_keys)
    expect(header_column_keys("admin_document_permissions")).to eq(permission_keys)
    expect(overview_keys).not_to include("company", "user", "access_level", "actions")
    expect(permission_keys).not_to include("project", "visibility_policy", "company_permissions", "user_permissions", "view_allowed", "download_allowed")
  end

  it "restores saved settings without changing document permission access levels" do
    permission = create(:document_permission, access_level: :download)
    RailsTablePreferences::Preference.create!(
      user: admin_user,
      table_key: "admin_document_permissions",
      name: "default",
      settings: {
        "columns" => [
          { "key" => "document", "visible" => true, "width" => 320, "order" => 1 },
          { "key" => "access_level", "visible" => true, "width" => 140, "order" => 2 },
          { "key" => "view_allowed", "visible" => false, "width" => 90, "order" => 3 }
        ],
        "filters" => {
          "access_level" => { "operator" => "equals", "value" => "download" },
          "view_allowed" => { "operator" => "equals", "value" => "1" }
        },
        "sorts" => [
          { "key" => "access_level", "direction" => "asc" },
          { "key" => "view_allowed", "direction" => "desc" }
        ]
      }
    )

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(permission.reload.access_level).to eq("download")
    expect(page_text).to include("ダウンロード")
    expect(action_targets).to include(
      edit_admin_document_permission_path(permission.public_id),
      admin_document_permission_path(permission.public_id)
    )

    settings = table_preference_surfaces("admin_document_permissions").map { |surface| table_preference_settings_for(surface) }
    expect(settings).to all(include(
      "columns" => contain_exactly(
        include("key" => "document", "visible" => true, "width" => 320, "order" => 1),
        include("key" => "access_level", "visible" => true, "width" => 140, "order" => 2)
      ),
      "filters" => { "access_level" => include("operator" => "equals", "value" => "download") },
      "sorts" => [include("key" => "access_level", "direction" => "asc")]
    ))
  end

  it "keeps the empty state outside table preference mounting" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ権限は登録されていません。登録後は、文書ごとの権限数と閲覧/ダウンロード内訳をここで確認できます。")
    expect(page_text).to include("個別付与行は登録後に表示されます。まずは上の「新規登録」で文書名と、会社またはユーザーのどちらかを指定して 1 件登録してください。")
    expect(page_text).to include("登録後は、会社別・ユーザー別の対象主体や権限内容をこの一覧で確認、編集できます。")
    expect(table_preference_surfaces("admin_document_permission_overview")).to be_empty
    expect(table_preference_surfaces("admin_document_permissions")).to be_empty
  end
end
