require "rails_helper"

RSpec.describe "Admin projects", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_body
    JSON.parse(response.body)
  end

  def project_names
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='name']").map { |cell| cell.text.squish }
  end

  def route_targets
    parsed_html.css("a[href], form[action]").filter_map { |node| node["href"] || node["action"] }
  end

  def clear_filter_links
    parsed_html.css("a[href]").select { |node| node.text.squish == "条件をクリア" }
  end

  def keyword_search_input
    parsed_html.at_css("input[name='q']")
  end

  def company_filter_picker
    parsed_html.at_css('select[name="company_id"]')
  end

  def project_form_company_picker
    parsed_html.at_css('select[name="project[company_id]"]')
  end

  def delete_confirm_messages
    parsed_html.css("form[data-turbo-confirm]").map { |form| form["data-turbo-confirm"] }
  end

  it "uses project codes for admin member links and rejects numeric ids" do
    project = create(:project, code: "CODE-001", name: "Code Routed Project")

    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(route_targets).to include(
      edit_admin_project_path(project.code),
      admin_project_path(project.code)
    )
    expect(route_targets).not_to include(
      edit_admin_project_path(project.id),
      admin_project_path(project.id)
    )

    get edit_admin_project_path(project.code)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件マスタ編集")

    get edit_admin_project_path(project.id)
    expect(response).to have_http_status(:not_found)

    patch admin_project_path(project.id), params: {
      project: {
        code: "NUMERIC-UPDATE",
        name: "Numeric Update",
        description: project.description,
        active: project.active
      }
    }
    expect(response).to have_http_status(:not_found)
    expect(project.reload.code).to eq("CODE-001")

    delete admin_project_path(project.id)
    expect(response).to have_http_status(:not_found)
    expect(Project.exists?(project.id)).to be(true)
  end

  it "includes project code and company cue in delete confirmations" do
    company = create(:company, name: "Confirm Company", domain: "confirm.example.com")
    create(:project, code: "CONFIRM-001", name: "Confirm Project", company:)
    create(:project, code: "NO-COMPANY", name: "No Company Project", company: nil)

    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(delete_confirm_messages).to include(
      "案件「Confirm Project」（コード: CONFIRM-001 / 企業: Confirm Company）を削除しますか？関連文書や所属設定に影響します。",
      "案件「No Company Project」（コード: NO-COMPANY / 企業: 企業未設定）を削除しますか？関連文書や所属設定に影響します。"
    )
  end

  it "filters projects by keyword across code, name, and description" do
    create(:project, code: "NEEDLE-001", name: "Code Match", description: "Plain text")
    create(:project, code: "NAME-001", name: "Needle Name", description: "Plain text")
    create(:project, code: "DESC-001", name: "Description Match", description: "contains needle text")
    create(:project, code: "OTHER-001", name: "Other Project", description: "Plain text")

    sign_in_as(admin_user)

    get admin_projects_path(q: "needle")

    expect(response).to have_http_status(:ok)
    expect(project_names).to contain_exactly("Code Match", "Needle Name", "Description Match")
    expect(page_text).to include("適用中:")
    expect(page_text).to include("検索: needle")
    expect(page_text).to include("検索結果: 3件")
  end

  it "shows the keyword search target and form-level length guard" do
    create(:project, code: "CUE-001", name: "Cue Project", description: "Search cue")

    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("コード・案件名・説明の断片で検索できます。最大100文字。")
    expect(keyword_search_input["placeholder"]).to eq("コード・案件名・説明")
    expect(keyword_search_input["maxlength"]).to eq("100")
  end

  it "returns bounded company search results by name and domain" do
    name_match = create(:company, domain: "alpha.example.com", name: "Alpha Company")
    domain_match = create(:company, domain: "needle.example.com", name: "Domain Match")

    max_length = Admin::ProjectsController::COMPANY_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    bounded_match = create(:company, domain: "bounded.example.com", name: "Target #{bounded_query}")
    suffix_only = create(:company, domain: "suffix.example.com", name: "Suffix only source")
    21.times do |index|
      create(:company, domain: format("limit-%02d.example.com", index), name: format("Limit Company %02d", index))
    end

    sign_in_as(admin_user)

    get company_search_admin_projects_path, params: { q: "alpha" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "Alpha Company / alpha.example.com")
    )

    get company_search_admin_projects_path, params: { q: "needle" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => domain_match.id, "text" => "Domain Match / needle.example.com")
    )

    get company_search_admin_projects_path, params: { q: "  #{bounded_query}   suffix  " }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => bounded_match.id, "text" => "Target #{bounded_query} / bounded.example.com")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get company_search_admin_projects_path, params: { q: "limit" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::ProjectsController::COMPANY_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("Limit Company"))
  end

  it "returns selected company options and ignores unknown selected values" do
    company = create(:company, domain: "restore.example.com", name: "Restore Company")

    sign_in_as(admin_user)

    get selected_company_admin_projects_path, params: { id: company.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => company.id,
      "text" => "Restore Company / restore.example.com"
    )

    get selected_company_admin_projects_path, params: { id: "missing" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get selected_company_admin_projects_path, params: { id: "none" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders remote company comboboxes for filter and form and restores selected companies" do
    company = create(:company, domain: "form.example.com", name: "Form Company")
    project = create(:project, code: "FORM", name: "Form Project", company:)

    sign_in_as(admin_user)

    get admin_projects_path(company_id: company.id.to_s)
    expect(response).to have_http_status(:ok)
    filter_picker = company_filter_picker
    expect(filter_picker).to be_present
    expect(filter_picker["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(filter_picker["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(filter_picker["data-rails-fields-kit--tom-select-url-value"]).to eq(company_search_admin_projects_path(format: :json))
    expect(filter_picker["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_company_admin_projects_path(format: :json))
    expect(filter_picker["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(filter_picker["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(filter_picker["data-rails-fields-kit--tom-select-search-field-value"]).to eq("text")
    expect(filter_picker["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(filter_picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")
    expect(filter_picker.at_css(%(option[value="#{company.id}"][selected]))&.text&.squish).to eq("Form Company / form.example.com")
    expect(page_text).to include("企業: Form Company")

    post admin_projects_path, params: {
      project: {
        code: "",
        name: "Invalid Project",
        description: "keeps selected company",
        active: "true",
        company_id: company.id
      }
    }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(project_form_company_picker.at_css(%(option[value="#{company.id}"][selected]))&.text&.squish).to eq("Form Company / form.example.com")

    get edit_admin_project_path(project.code)
    expect(response).to have_http_status(:ok)
    expect(project_form_company_picker.at_css(%(option[value="#{company.id}"][selected]))&.text&.squish).to eq("Form Company / form.example.com")
  end

  it "combines active and company filters" do
    company = create(:company, name: "Filter Company", domain: "filter.example.com")
    other_company = create(:company, name: "Other Company", domain: "other.example.com")
    create(:project, code: "ACTIVE", name: "Active Same Company", active: true, company:)
    create(:project, code: "INACTIVE", name: "Inactive Same Company", active: false, company:)
    create(:project, code: "OTHERCO", name: "Inactive Other Company", active: false, company: other_company)
    create(:project, code: "UNSET", name: "Inactive Unset Company", active: false, company: nil)

    sign_in_as(admin_user)

    get admin_projects_path(active: "false", company_id: company.id.to_s)

    expect(response).to have_http_status(:ok)
    expect(project_names).to eq(["Inactive Same Company"])
    expect(page_text).to include("状態: 無効")
    expect(page_text).to include("企業: Filter Company")
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).to include("表示設定は列の表示・幅を調整し、絞り込みは一覧に出す案件を切り替えます。")
  end

  it "filters projects without a company separately from company projects" do
    company = create(:company, name: "Assigned Company", domain: "assigned.example.com")
    create(:project, code: "UNSET", name: "Unset Company Project", company: nil)
    create(:project, code: "ASSIGNED", name: "Assigned Company Project", company:)

    sign_in_as(admin_user)

    get admin_projects_path(company_id: "none")

    expect(response).to have_http_status(:ok)
    expect(project_names).to eq(["Unset Company Project"])
    expect(page_text).to include("未設定")
    expect(page_text).to include("企業: 企業未設定")
    expect(company_filter_picker.at_css('option[value="none"][selected]')&.text&.squish).to eq("企業未設定")
  end

  it "shows the clear action only when project filters are active" do
    company = create(:company, name: "Clear Company", domain: "clear.example.com")
    create(:project, code: "CLEAR", name: "Clear Action Project", company:)

    sign_in_as(admin_user)

    get admin_projects_path
    expect(response).to have_http_status(:ok)
    expect(clear_filter_links).to be_empty

    [
      { q: "Clear" },
      { active: "true" },
      { company_id: company.id.to_s },
      { company_id: "none" }
    ].each do |params|
      get admin_projects_path(params)

      expect(response).to have_http_status(:ok)
      expect(clear_filter_links.map { |link| link["href"] }).to include(admin_projects_path)
    end
  end

  it "ignores unsupported filter values without raising errors" do
    create(:project, code: "ACTIVE", name: "Active Project", active: true)
    create(:project, code: "INACTIVE", name: "Inactive Project", active: false)

    sign_in_as(admin_user)

    get admin_projects_path(active: "archived", company_id: "not-a-company")

    expect(response).to have_http_status(:ok)
    expect(project_names).to contain_exactly("Active Project", "Inactive Project")
    expect(clear_filter_links).to be_empty
  end

  it "forbids external users from company picker JSON endpoints" do
    company = create(:company)

    sign_in_as(external_user)

    get company_search_admin_projects_path, params: { q: company.domain }
    expect(response).to have_http_status(:forbidden)

    get selected_company_admin_projects_path, params: { id: company.id }
    expect(response).to have_http_status(:forbidden)
  end

  it "separates no projects from filtered empty results" do
    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ案件は登録されていません。")
    expect(page_text).not_to include("検索条件に一致する案件はありません。")
    expect(clear_filter_links).to be_empty

    create(:project, code: "EXISTING", name: "Existing Project")

    get admin_projects_path(q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する案件はありません。")
    expect(page_text).not_to include("まだ案件は登録されていません。")
    expect(clear_filter_links.map { |link| link["href"] }).to eq([admin_projects_path, admin_projects_path])
  end
end
