require "rails_helper"

RSpec.describe "Admin document permissions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def expect_server_rendered_tab_contract(active_tab_id:, active_panel_id:)
    tablist = parsed_html.at_css("nav[role='tablist']")
    tabs = tablist.css("[role='tab']")
    active_tab = parsed_html.at_css("##{active_tab_id}")
    expected_controls = {
      "document-permissions-assignments-tab" => "document-permissions-assignments-panel",
      "document-permissions-overview-tab" => "document-permissions-overview-panel"
    }
    inactive_panel_id = (expected_controls.values - [active_panel_id]).sole

    expect(tablist["data-controller"].to_s.split).to include("server-rendered-tabs")
    expect(tabs.size).to eq(2)
    expect(tabs.to_h { [_1["id"], _1["aria-controls"]] }).to eq(expected_controls)
    expect(tabs).to all(satisfy { _1["data-server-rendered-tabs-target"] == "tab" })
    expect(tabs).to all(satisfy { _1["data-action"].to_s.split.include?("keydown->server-rendered-tabs#keydown") })
    expect(active_tab["aria-selected"]).to eq("true")
    expect(active_tab["tabindex"]).to eq("0")
    expect(tabs.reject { _1["id"] == active_tab_id }.map { _1["tabindex"] }.uniq).to eq(["-1"])
    expect(parsed_html.at_css("##{active_panel_id}[role='tabpanel'][aria-labelledby='#{active_tab_id}']")).to be_present
    expect(parsed_html.at_css("##{inactive_panel_id}")).to be_nil
  end

  def parsed_json
    JSON.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def select_placeholder(field_name)
    parsed_html.at_css(%(select[name="#{field_name}"]))&.[]("placeholder")
  end

  def document_select
    parsed_html.at_css('select[name="document_permission[document_id]"]')
  end

  def selected_document_option
    document_select.at_css("option[selected]")
  end

  def document_error_surface
    parsed_html.at_css("#document_permission_document_id_error_surface")
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

  def link_texts
    parsed_html.css("a[href]").map { _1.text.squish }
  end

  def clear_filter_link
    parsed_html.css("a[href]").find { _1.text.squish == "条件をクリア" }
  end

  def node_ids
    parsed_html.css("[id]").map { _1["id"] }
  end

  def section_text(heading)
    section = parsed_html.css("section.card").find do |candidate|
      candidate.at_css("h2")&.text&.squish == heading
    end

    section&.text&.squish.to_s
  end

  def overview_section_text
    section_text("文書別の権限概要")
  end

  def permissions_section_text
    section_text("権限一覧")
  end

  it "renders only the assignments table for the default view" do
    create(:document_permission)
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect_server_rendered_tab_contract(
      active_tab_id: "document-permissions-assignments-tab",
      active_panel_id: "document-permissions-assignments-panel"
    )
    expect(parsed_html.at_css("#document-permissions-assignments-panel")).to be_present
    expect(parsed_html.at_css("#document-permissions-overview-panel")).to be_nil
    expect(parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_document_permissions"]')).to be_present
    expect(parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_document_permission_overview"]')).to be_nil
  end

  it "renders only the overview table for the overview view" do
    create(:document_permission)
    sign_in_as(admin_user)

    get admin_document_permissions_path(view: "overview")

    expect(response).to have_http_status(:ok)
    expect_server_rendered_tab_contract(
      active_tab_id: "document-permissions-overview-tab",
      active_panel_id: "document-permissions-overview-panel"
    )
    expect(parsed_html.at_css("#document-permissions-overview-panel")).to be_present
    expect(parsed_html.at_css("#document-permissions-assignments-panel")).to be_nil
    expect(parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_document_permission_overview"]')).to be_present
    expect(parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_document_permissions"]')).to be_nil
    expect(parsed_html.at_css('input[name="view"]')["value"]).to eq("overview")
  end

  it "renders the document field as the rails_fields_kit error-surface canary" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(document_select["data-controller"]).to include("document-permission-error-surface")
    expect(document_select["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(document_select["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(document_select["data-rails-fields-kit--tom-select-url-value"]).to eq(document_search_admin_document_permissions_path(format: :json))
    expect(document_select["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_document_admin_document_permissions_path(format: :json))
    expect(document_select["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(document_select["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")
    expect(document_select["placeholder"]).to eq("文書名・URL識別子・案件名で検索")
    expect(document_select.css("option")).to be_empty
    expect(document_select["data-action"]).to include("rails-fields-kit--tom-select:selected-load-error->document-permission-error-surface#selectedLoadError")
    expect(document_select["data-action"]).to include("rails-fields-kit--tom-select:selected-load->document-permission-error-surface#clear")
    expect(document_select["data-action"]).to include("rails-fields-kit--tom-select:change->document-permission-error-surface#clear")
    expect(document_select["aria-describedby"].to_s.split).to include("document_permission_document_id_error_surface")
    expect(document_select["data-rails-fields-kit--tom-select-error-surface-id-value"]).to eq("document_permission_document_id_error_surface")
    expect(document_error_surface["role"]).to eq("status")
    expect(document_error_surface["aria-live"]).to eq("polite")
    expect(document_error_surface["hidden"]).to eq("hidden")
    expect(document_error_surface["class"]).to include("notice", "alert", "rfk-tom-select-error-surface")
  end

  it "keeps company and user fields out of the error-surface canary" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    company_select = parsed_html.at_css('select[name="document_permission[company_id]"]')
    user_select = parsed_html.at_css('select[name="document_permission[user_id]"]')

    expect(company_select["data-controller"]).not_to include("document-permission-error-surface")
    expect(user_select["data-controller"]).not_to include("document-permission-error-surface")
    expect(company_select["data-rails-fields-kit--tom-select-error-surface-id-value"]).to be_nil
    expect(user_select["data-rails-fields-kit--tom-select-error-surface-id-value"]).to be_nil
  end

  it "returns document search options for the remote document field" do
    project = create(:project, name: "Alpha Project")
    matching_document = create(:document, title: "Operations Runbook", slug: "ops-runbook", project:)
    project_match = create(:document, title: "Portal Guide", slug: "portal-guide", project:)
    create(:document, title: "Another Document", slug: "another-document", project: create(:project, name: "Beta Project"))

    sign_in_as(admin_user)

    get document_search_admin_document_permissions_path(format: :json), params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["options"]).to contain_exactly(
      { "value" => matching_document.id, "text" => "Operations Runbook / Alpha Project" },
      { "value" => project_match.id, "text" => "Portal Guide / Alpha Project" }
    )

    get document_search_admin_document_permissions_path(format: :json), params: { q: "ops-run" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["options"]).to eq([
      { "value" => matching_document.id, "text" => "Operations Runbook / Alpha Project" }
    ])
  end

  it "loads the selected document option for edit and validation redisplay" do
    project = create(:project, name: "Selected Project")
    document = create(:document, title: "Selected Manual", project:)
    company = create(:company, name: "Customer Company")
    permission = create(:document_permission, document:, company:, access_level: :view)

    sign_in_as(admin_user)

    get selected_document_admin_document_permissions_path(format: :json), params: { id: document.id }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["option"]).to eq({ "value" => document.id, "text" => "Selected Manual / Selected Project" })

    get selected_document_admin_document_permissions_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["option"]).to be_nil

    get edit_admin_document_permission_path(permission.public_id)

    expect(response).to have_http_status(:ok)
    expect(selected_document_option["value"]).to eq(document.id.to_s)
    expect(selected_document_option.text).to eq("Selected Manual / Selected Project")
  end

  it "keeps document search endpoints admin-only" do
    external_user = create(:user, :external)

    sign_in_as(external_user)

    get document_search_admin_document_permissions_path(format: :json), params: { q: "manual" }

    expect(response).to have_http_status(:forbidden)

    get selected_document_admin_document_permissions_path(format: :json), params: { id: 1 }

    expect(response).to have_http_status(:forbidden)
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

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("入力内容を確認してください。")
    expect(page_text).to include("適用対象の選択を確認してください。")
    expect(page_text).to include("適用対象は会社かユーザーのどちらか一方だけを指定してください。")
    expect(page_text).to include("会社全体に付与するか、特定ユーザー1名に付与するかを選びます。")
    expect(page_text).not_to include("company_id and user_id cannot both be set")
    expect(select_placeholder("document_permission[company_id]")).to eq("会社向けに付与する場合に選択")
    expect(select_placeholder("document_permission[user_id]")).to eq("ユーザー向けに付与する場合に選択")
    expect(selected_document_option["value"]).to eq(document.id.to_s)
    expect(selected_document_option.text).to eq("Permission Target / #{document.project.name}")
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
