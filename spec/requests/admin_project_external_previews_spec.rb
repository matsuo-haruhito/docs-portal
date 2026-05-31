require "rails_helper"

RSpec.describe "Admin project external previews", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:, email_address: "viewer@example.com") }
  let(:other_external_user) { create(:user, :external, company:, email_address: "viewer2@example.com") }
  let(:company) { create(:company, name: "Preview Co") }
  let(:project) { create(:project, code: "PVWADM", name: "Preview Admin") }

  def create_document_with_file(title:, slug:, visibility_policy:, access_level: :view)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, status: :published)
    document.update!(latest_version: version)
    file = create(:document_file, document_version: version, file_name: "#{slug}.txt")
    create(:document_permission, document:, company:, access_level:) unless visibility_policy == :internal_only
    [document, file]
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
end