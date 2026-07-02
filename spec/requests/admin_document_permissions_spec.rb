require "rails_helper"

RSpec.describe "Admin document permissions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
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

  it "shows empty-state guidance when no document permissions exist" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("文書別の権限概要", "適用対象", "権限一覧")
    expect(page_text.scan("まだ権限は登録されていません。").size).to eq(1)
    expect(page_text).to include("まだ権限は登録されていません。登録後は、文書ごとの権限数と閲覧/ダウンロード内訳をここで確認できます。")
    expect(page_text).to include("個別付与行は登録後に表示されます。まずは上の「新規登録」で文書名と、会社またはユーザーのどちらかを指定して 1 件登録してください。")
    expect(page_text).to include("登録後は、会社別・ユーザー別の対象主体や権限内容をこの一覧で確認、編集できます。")
    expect(page_text).to include("会社全体に付与するか、特定ユーザー1名に付与するかを選びます。")
    expect(page_text).to include("会社全体に同じ権限を付与する場合だけ選択します。")
    expect(page_text).to include("特定の1名にだけ権限を付与する場合だけ選択します。")
    expect(page_text).to include("表示中: 0件 / 登録済みの文書権限を表示")
    expect(select_placeholder("document_permission[company_id]")).to eq("会社向けに付与する場合に選択")
    expect(select_placeholder("document_permission[user_id]")).to eq("ユーザー向けに付与する場合に選択")
    expect(link_texts).not_to include("条件をクリア")
    expect(page_text).not_to include("表示中: 0件 / 条件に一致する文書権限を表示")
    expect(page_text).not_to include("会社単位かユーザー単位のどちらか一方を指定してください。")
    expect(page_text).not_to include("下段の「権限一覧」にある個別付与行")
    expect(page_text).not_to include("下段の個別権限を見る")
    expect(page_text).not_to include("この文書の個別付与行")
    expect(page_text).not_to include("権限概要の表示設定")
    expect(page_text).not_to include("権限一覧の表示設定")
    expect(table_preference_column_keys).to be_empty
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
    expect(page_text).to include("件数は下段の「権限一覧」にある個別付与行を文書単位で集計したものです。")
    expect(link_texts).to include("下段の個別権限を見る")
    expect(page_text).to include("この文書の個別付与行（会社単位・ユーザー単位）")
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

  it "filters overview and permission rows by project" do
    target_project = create(:project, code: "TARGET", name: "Target Project")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    target_document = create(:document, project: target_project, title: "Target Project Guide")
    other_document = create(:document, project: other_project, title: "Other Project Guide")
    create(:document_permission, document: target_document, company: create(:company, name: "Target Company"))
    create(:document_permission, document: other_document, company: create(:company, name: "Other Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(project_id: target_project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("有効な条件: 案件: TARGET / Target Project")
    expect(overview_section_text).to include("Target Project Guide")
    expect(overview_section_text).not_to include("Other Project Guide")
    expect(permissions_section_text).to include("Target Project Guide")
    expect(permissions_section_text).to include("Target Company")
    expect(permissions_section_text).not_to include("Other Project Guide")
    expect(permissions_section_text).not_to include("Other Company")
    expect(action_targets).to include(project_document_path(target_project, target_document.slug))
    expect(action_targets).not_to include(project_document_path(other_project, other_document.slug))
  end

  it "filters overview and permission rows by document title or slug" do
    title_document = create(:document, title: "Alpha Operations", slug: "alpha-ops")
    slug_document = create(:document, title: "Beta Manual", slug: "beta-visible-slug")
    other_document = create(:document, title: "Gamma Manual", slug: "gamma")
    create(:document_permission, document: title_document, company: create(:company, name: "Alpha Company"))
    create(:document_permission, document: slug_document, company: create(:company, name: "Beta Company"))
    create(:document_permission, document: other_document, company: create(:company, name: "Gamma Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "alpha")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書: alpha")
    expect(overview_section_text).to include("Alpha Operations")
    expect(overview_section_text).not_to include("Beta Manual")
    expect(permissions_section_text).to include("Alpha Company")
    expect(permissions_section_text).not_to include("Beta Company")

    get admin_document_permissions_path(q: "visible-slug")

    expect(response).to have_http_status(:ok)
    expect(overview_section_text).to include("Beta Manual")
    expect(overview_section_text).not_to include("Alpha Operations")
    expect(permissions_section_text).to include("Beta Company")
    expect(permissions_section_text).not_to include("Gamma Company")
  end

  it "filters overview counts and permission rows by access level and target type" do
    document = create(:document, title: "Scoped Permission Guide")
    company = create(:company, name: "Company Scope")
    user = create(:user, :external, name: "User Scope", email_address: "user-scope@example.com")
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_permission, document:, user:, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path(access_level: "download", target_type: "user")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("権限: ダウンロード")
    expect(page_text).to include("付与先: ユーザー単位")
    expect(overview_section_text).to include("Scoped Permission Guide")
    expect(permissions_section_text).to include("Scoped Permission Guide")
    expect(permissions_section_text).to include("User Scope")
    expect(permissions_section_text).to include("ダウンロード")
    expect(permissions_section_text).not_to include("Company Scope")
  end

  it "shows the clear action for each active filter type" do
    target_project = create(:project, name: "Clear Link Project")

    sign_in_as(admin_user)

    [
      { q: "manual" },
      { project_id: target_project.id },
      { access_level: "view" },
      { target_type: "company" }
    ].each do |params|
      get admin_document_permissions_path(params)

      expect(response).to have_http_status(:ok)
      expect(clear_filter_link["href"]).to eq(admin_document_permissions_path)
    end
  end

  it "shows a filtered empty state without mixing it with the unregistered state" do
    document = create(:document, title: "Existing Permission Guide")
    create(:document_permission, document:, company: create(:company, name: "Existing Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件 / 条件に一致する文書権限を表示")
    expect(overview_section_text).to include("条件に一致する文書権限概要はありません。")
    expect(permissions_section_text).to include("条件に一致する文書権限はありません。")
    expect(clear_filter_link["href"]).to eq(admin_document_permissions_path)
    expect(overview_section_text).not_to include("まだ権限は登録されていません。")
    expect(permissions_section_text).not_to include("まずは上の「新規登録」")
  end

  it "ignores invalid filters without returning an error" do
    document = create(:document, title: "Invalid Filter Fallback")
    create(:document_permission, document:, company: create(:company, name: "Fallback Company"))

    sign_in_as(admin_user)

    get admin_document_permissions_path(project_id: "999999", access_level: "owner", target_type: "team")

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("有効な条件:")
    expect(overview_section_text).to include("Invalid Filter Fallback")
    expect(permissions_section_text).to include("Fallback Company")
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
