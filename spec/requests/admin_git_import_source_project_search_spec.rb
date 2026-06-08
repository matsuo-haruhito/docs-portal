require "rails_helper"

RSpec.describe "Admin git import source project search", type: :request do
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

  def project_select
    parsed_html.at_css('select[name="git_import_source[project_id]"]')
  end

  def selected_project_option
    project_select.at_css("option[selected]")
  end

  it "renders the project field as a remote RFK combobox without preloading all projects" do
    create_list(:project, 3)

    sign_in_as(admin_user)

    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(project_select["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(project_select["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(project_select["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_git_import_sources_path(format: :json))
    expect(project_select["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_git_import_sources_path(format: :json))
    expect(project_select["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(project_select["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(project_select["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(project_select["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")
    expect(project_select["placeholder"]).to eq("案件コード・案件名で検索")
    expect(project_select.css("option")).to be_empty
  end

  it "returns project search options by code or name with a bounded result count" do
    code_match = create(:project, code: "ALPHA001", name: "Code Hit")
    name_match = create(:project, code: "BETA001", name: "Alpha Name Hit")
    create(:project, code: "GAMMA001", name: "Unrelated")
    21.times do |index|
      create(:project, code: "CAP#{index.to_s.rjust(3, '0')}", name: "Capped Project #{index}")
    end

    sign_in_as(admin_user)

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["options"]).to contain_exactly(
      { "value" => code_match.id, "text" => "ALPHA001 / Code Hit" },
      { "value" => name_match.id, "text" => "BETA001 / Alpha Name Hit" }
    )

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "cap" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["options"].size).to eq(Admin::GitImportSourcesController::PROJECT_SEARCH_LIMIT)
    expect(parsed_json["options"].map { _1["text"] }).to include("CAP000 / Capped Project 0")
    expect(parsed_json["options"].map { _1["text"] }).not_to include("CAP020 / Capped Project 20")
  end

  it "loads the selected project option for edit and validation redisplay" do
    project = create(:project, code: "SEL001", name: "Selected Project")
    source = create(:git_import_source, project:)

    sign_in_as(admin_user)

    get selected_project_admin_git_import_sources_path(format: :json), params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["option"]).to eq({ "value" => project.id, "text" => "SEL001 / Selected Project" })

    get selected_project_admin_git_import_sources_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(parsed_json["option"]).to be_nil

    get edit_admin_git_import_source_path(source.public_id)

    expect(response).to have_http_status(:ok)
    expect(selected_project_option["value"]).to eq(project.id.to_s)
    expect(selected_project_option.text).to eq("SEL001 / Selected Project")

    post admin_git_import_sources_path, params: {
      git_import_source: {
        project_id: project.id,
        provider: "github",
        repository_full_name: "",
        branch: "main",
        source_path: "docs",
        auth_type: "github_app",
        enabled: true
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("入力内容を確認してください。")
    expect(selected_project_option["value"]).to eq(project.id.to_s)
    expect(selected_project_option.text).to eq("SEL001 / Selected Project")
  end

  it "keeps project picker endpoints admin-only" do
    external_user = create(:user, :external)

    sign_in_as(external_user)

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "project" }

    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_git_import_sources_path(format: :json), params: { id: 1 }

    expect(response).to have_http_status(:forbidden)
  end
end
