require "rails_helper"

RSpec.describe "Admin project external previews", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:, email_address: "viewer@example.com") }
  let(:other_external_user) { create(:user, :external, company:, email_address: "viewer2@example.com") }
  let(:company) { create(:company, name: "Preview Co", domain: "preview.example") }
  let(:project) { create(:project, code: "PVWADM", name: "Preview Admin") }

  def create_document_with_file(title:, slug:, visibility_policy:, access_level: :view)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, status: :published)
    document.update!(latest_version: version)
    file = create(:document_file, document_version: version, file_name: "#{slug}.txt")
    create(:document_permission, document:, company:, access_level:) unless visibility_policy == :internal_only
    [document, file]
  end

  def parsed_json
    JSON.parse(response.body)
  end

  def option_values
    parsed_json.fetch("options").map { _1.fetch("value") }
  end

  def option_texts
    parsed_json.fetch("options").map { _1.fetch("text") }
  end

  def preview_result_headings
    Nokogiri::HTML(response.body).css(".card h2").map { _1.text.squish }
  end

  before do
    create(:project_membership, project:, user: external_user)
    create(:project_membership, project:, user: other_external_user)
  end

  it "shows user-based external visibility preview and records an audit log" do
    create_document_with_file(title: "Visible Doc", slug: "visible-doc", visibility_policy: :restricted_external, access_level: :download)
    create_document_with_file(title: "Hidden Doc", slug: "hidden-doc", visibility_policy: :internal_only)

    sign_in_as(admin_user)

    expect(external_preview_admin_project_path(project)).to eq("/admin/projects/PVWADM/external_preview")

    expect do
      get external_preview_admin_project_path(project), params: { user_id: external_user.id }
    end.to change(AccessLog.where(target_type: "external_preview"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("外部表示プレビュー中")
    expect(response.body).to include("viewer@example.com")
    expect(response.body).to include("Visible Doc")
    expect(response.body).to include("Hidden Doc")

    log = AccessLog.order(:id).last
    expect(log.action_type).to eq("view")
    expect(log.target_type).to eq("external_preview")
    expect(log.target_name).to eq("user:viewer@example.com")
    expect(log.project).to eq(project)
  end

  it "shows company-based external visibility preview for all active viewers in the company" do
    create_document_with_file(title: "Visible Doc", slug: "visible-doc", visibility_policy: :restricted_external, access_level: :view)
    other_company = create(:company, name: "Other Co")
    create(:user, :external, company: other_company, email_address: "other-company@example.com")
    create(:user, :external, company:, email_address: "inactive@example.com", active: false)

    sign_in_as(admin_user)

    expect do
      get external_preview_admin_project_path(project), params: { company_id: company.id }
    end.to change(AccessLog.where(target_type: "external_preview"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対象会社")
    expect(response.body).to include("Preview Co")
    expect(response.body).to include("2名の有効ユーザー")
    expect(preview_result_headings).to include("viewer@example.com", "viewer2@example.com")
    expect(preview_result_headings).not_to include("other-company@example.com", "inactive@example.com")

    log = AccessLog.order(:id).last
    expect(log.company).to eq(company)
    expect(log.project).to eq(project)
    expect(log.target_name).to eq("company:Preview Co viewers=2")
  end

  it "searches active external preview users without exposing inactive or internal users" do
    internal_user = create(:user, :internal, email_address: "internal-viewer@example.com")
    inactive_user = create(:user, :external, company:, email_address: "inactive-viewer@example.com", active: false)
    master_admin = create(:user, :company_master_admin, company:, name: "Company Master", email_address: "master@example.com")

    sign_in_as(admin_user)

    get external_preview_user_search_admin_project_path(project, format: :json), params: { q: "viewer" }

    expect(response).to have_http_status(:ok)
    expect(option_values).to include(external_user.id, other_external_user.id)
    expect(option_values).not_to include(internal_user.id, inactive_user.id)
    expect(option_texts.join(" ")).to include("Preview Co")

    get external_preview_user_search_admin_project_path(project, format: :json), params: { q: "master" }

    expect(option_values).to include(master_admin.id)
  end

  it "searches companies that have active external preview users" do
    other_company = create(:company, name: "Dormant Preview Co", domain: "dormant.example")
    create(:user, :external, company: other_company, email_address: "dormant@example.com", active: false)

    sign_in_as(admin_user)

    get external_preview_company_search_admin_project_path(project, format: :json), params: { q: "preview" }

    expect(response).to have_http_status(:ok)
    expect(option_values).to include(company.id)
    expect(option_values).not_to include(other_company.id)
    expect(option_texts).to include("Preview Co / preview.example")
  end

  it "restores selected user and company options outside the initial candidate payload" do
    selected_company = create(:company, name: "Zeta Preview", domain: "zeta.example")
    selected_user = create(:user, :external, company: selected_company, name: "Zeta Viewer", email_address: "zeta@example.com")

    sign_in_as(admin_user)

    get selected_external_preview_user_admin_project_path(project, format: :json), params: { id: selected_user.id }

    expect(response).to have_http_status(:ok)
    expect(parsed_json.fetch("option")).to include(
      "value" => selected_user.id,
      "text" => "Zeta Viewer / zeta@example.com / Zeta Preview"
    )

    get selected_external_preview_company_admin_project_path(project, format: :json), params: { id: selected_company.id }

    expect(response).to have_http_status(:ok)
    expect(parsed_json.fetch("option")).to include(
      "value" => selected_company.id,
      "text" => "Zeta Preview / zeta.example"
    )
  end

  it "does not restore selected values outside the external viewer boundary" do
    internal_user = create(:user, :internal, email_address: "internal-only@example.com")
    dormant_company = create(:company, name: "Dormant Co")

    sign_in_as(admin_user)

    get selected_external_preview_user_admin_project_path(project, format: :json), params: { id: internal_user.id }
    expect(parsed_json.fetch("option")).to be_nil

    get selected_external_preview_company_admin_project_path(project, format: :json), params: { id: dormant_company.id }
    expect(parsed_json.fetch("option")).to be_nil
  end

  it "keeps the company preview resolver query-scoped instead of filtering loaded preview candidates" do
    controller_source = Rails.root.join("app/controllers/admin/project_external_previews_controller.rb").read

    expect(controller_source).to include("where(company_id: @selected_company.id)")
    expect(controller_source).not_to include("@preview_users.select")
  end

  it "links to the external preview from project edit" do
    sign_in_as(admin_user)

    get edit_admin_project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("外部表示プレビュー")
    expect(response.body).to include(external_preview_admin_project_path(project))
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get external_preview_admin_project_path(project), params: { user_id: external_user.id }

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids external users from remote selector endpoints" do
    sign_in_as(external_user)

    get external_preview_user_search_admin_project_path(project, format: :json), params: { q: "viewer" }

    expect(response).to have_http_status(:forbidden)
  end
end