require "rails_helper"

RSpec.describe "Admin document usage report project select restore", type: :request do
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

  def selected_project_option
    parsed_html.at_css("select[name='project_id'] option[selected]")
  end

  it "keeps a selected project visible even when it is outside the bounded initial options" do
    Admin::BoundedProjectOptions::PROJECT_SELECT_OPTION_LIMIT.times do |index|
      create(
        :project,
        code: "RFKIN#{index.to_s.rjust(3, '0')}",
        name: "A bounded project #{index.to_s.rjust(3, '0')}"
      )
    end
    selected_project = create(:project, code: "RFKOUT", name: "ZZZ Selected Restore Project")
    create(:document, project: selected_project, title: "Selected Restore Manual", slug: "selected-restore-manual")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: selected_project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件:", "ZZZ Selected Restore Project", "RFKOUT")
    expect(page_text).to include("Selected Restore Manual")

    expect(selected_project_option).to be_present
    expect(selected_project_option["value"]).to eq(selected_project.id.to_s)
    expect(selected_project_option.text.squish).to eq("RFKOUT / ZZZ Selected Restore Project")
    expect(project_select_options.map { _1["value"] }).to include(selected_project.id.to_s)
  end

  it "returns the selected project option for RFK restore requests and nil for unknown projects" do
    selected_project = create(:project, code: "RFKSEL", name: "Selected Endpoint Project")

    sign_in_as(admin_user)

    get selected_project_admin_document_usage_reports_path(format: :json, id: selected_project.id)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("option")).to eq(
      "value" => selected_project.id,
      "text" => "RFKSEL / Selected Endpoint Project"
    )

    get selected_project_admin_document_usage_reports_path(format: :json, id: "999999")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("option")).to be_nil
  end
end
