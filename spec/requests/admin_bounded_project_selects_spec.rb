require "csv"
require "rails_helper"

RSpec.describe "Admin bounded project selects", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_select_options
    parsed_html.css("select[name='project_id'] option")
  end

  def project_select_values
    project_select_options.map { _1["value"] }
  end

  def selected_project_option
    parsed_html.at_css("select[name='project_id'] option[selected]")
  end

  def create_project_candidates(count: Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT + 1)
    count.times.map do |index|
      create(:project, code: format("BP%03d", index), name: format("Bounded Project %03d", index))
    end
  end

  it "bounds document usage report project candidates while preserving an out-of-window selected project" do
    projects = create_project_candidates
    selected_project = create(:project, code: "TAIL", name: "Zzz Selected Project")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(project_select_options.size).to eq(Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT + 1)
    expect(project_select_values).to include(projects.first.id.to_s)
    expect(project_select_values).not_to include(projects.last.id.to_s, selected_project.id.to_s)

    get admin_document_usage_reports_path(project_id: selected_project.id)

    expect(response).to have_http_status(:ok)
    expect(project_select_options.size).to eq(Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT + 2)
    expect(project_select_values).to include(selected_project.id.to_s)
    expect(selected_project_option["value"]).to eq(selected_project.id.to_s)
    expect(page_text).to include("Zzz Selected Project")
    expect(page_text).to include("表示中: 0件")
  end

  it "bounds read confirmation project candidates while preserving an out-of-window selected project" do
    projects = create_project_candidates
    selected_project = create(:project, code: "TAIL", name: "Zzz Selected Project")

    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(project_select_options.size).to eq(Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT + 1)
    expect(project_select_values).to include(projects.first.id.to_s)
    expect(project_select_values).not_to include(projects.last.id.to_s, selected_project.id.to_s)

    get admin_read_confirmations_path(project_id: selected_project.id)

    expect(response).to have_http_status(:ok)
    expect(project_select_options.size).to eq(Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT + 2)
    expect(project_select_values).to include(selected_project.id.to_s)
    expect(selected_project_option["value"]).to eq(selected_project.id.to_s)
    expect(page_text).to include("Zzz Selected Project")
    expect(page_text).to include("表示中: 0件")
  end

  it "keeps invalid project_id CSV requests from exporting cross-project data" do
    selected_project = create(:project, code: "SAFE", name: "Safe Project")
    document = create(:document, project: selected_project, title: "Safe Manual", slug: "safe-manual")
    viewer = create(:user, :external)
    create(:access_log, project: selected_project, document:, user: viewer, action_type: :view)
    create(:read_confirmation, document:, user: viewer)

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: "999999", format: :csv)

    expect(response).to redirect_to(admin_document_usage_reports_path)

    get admin_read_confirmations_path(project_id: "999999", format: :csv)

    expect(response).to redirect_to(admin_read_confirmations_path)
  end
end
