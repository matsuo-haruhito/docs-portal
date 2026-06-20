require "rails_helper"

RSpec.describe "Admin read confirmation remote filters", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "RC", name: "Read Confirmation Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:other_document) { create(:document, project: other_project, title: "Outside", slug: "outside") }

  def json_body
    JSON.parse(response.body)
  end

  def option_texts
    json_body.fetch("options").map { _1.fetch("text") }
  end

  def create_confirmation(company_name:, company_domain:, user_name:, email:, target_document: document)
    company = create(:company, name: company_name, domain: company_domain)
    user = create(:user, :external, company:, name: user_name, email_address: email)
    create(:read_confirmation, document: target_document, user:)
    [company, user]
  end

  it "returns bounded company options inside the selected project and searches name or domain" do
    matching_company, = create_confirmation(
      company_name: "Alpha Client",
      company_domain: "alpha.example",
      user_name: "Alpha Reader",
      email: "alpha@example.com"
    )
    create_confirmation(
      company_name: "Beta Client",
      company_domain: "beta.example",
      user_name: "Beta Reader",
      email: "beta@example.com"
    )
    create_confirmation(
      company_name: "Outside Alpha",
      company_domain: "outside-alpha.example",
      user_name: "Outside Reader",
      email: "outside-alpha@example.com",
      target_document: other_document
    )

    sign_in_as(admin_user)

    get company_search_admin_read_confirmations_path(format: :json), params: { project_id: project.id, q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([
      { "value" => matching_company.id, "text" => "Alpha Client / alpha.example" }
    ])

    get company_search_admin_read_confirmations_path(format: :json), params: { project_id: project.id, q: "example" }

    expect(response).to have_http_status(:ok)
    expect(option_texts.size).to eq(2)
    expect(option_texts).to include("Alpha Client / alpha.example", "Beta Client / beta.example")
    expect(option_texts).not_to include("Outside Alpha / outside-alpha.example")
  end

  it "returns selected companies only when they belong to the selected project" do
    project_company, = create_confirmation(
      company_name: "Project Client",
      company_domain: "project.example",
      user_name: "Project Reader",
      email: "project-reader@example.com"
    )
    outside_company, = create_confirmation(
      company_name: "Outside Client",
      company_domain: "outside.example",
      user_name: "Outside Reader",
      email: "outside-reader@example.com",
      target_document: other_document
    )

    sign_in_as(admin_user)

    get selected_company_admin_read_confirmations_path(format: :json), params: { project_id: project.id, id: project_company.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to eq(
      "value" => project_company.id,
      "text" => "Project Client / project.example"
    )

    get selected_company_admin_read_confirmations_path(format: :json), params: { project_id: project.id, id: outside_company.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "returns user options inside the selected project and optional company boundary" do
    company, matching_user = create_confirmation(
      company_name: "Client A",
      company_domain: "client-a.example",
      user_name: "Remote Reader",
      email: "remote-reader@example.com"
    )
    create_confirmation(
      company_name: "Client B",
      company_domain: "client-b.example",
      user_name: "Other Reader",
      email: "other-reader@example.com"
    )
    create_confirmation(
      company_name: "Outside Client",
      company_domain: "outside.example",
      user_name: "Remote Outside",
      email: "remote-outside@example.com",
      target_document: other_document
    )

    sign_in_as(admin_user)

    get user_search_admin_read_confirmations_path(format: :json), params: { project_id: project.id, company_id: company.id, q: "remote" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([
      { "value" => matching_user.id, "text" => "Remote Reader / remote-reader@example.com / Client A" }
    ])

    get user_search_admin_read_confirmations_path(format: :json), params: { project_id: project.id, q: "client-b" }

    expect(response).to have_http_status(:ok)
    expect(option_texts).to eq(["Other Reader / other-reader@example.com / Client B"])
  end

  it "restores selected users beyond the initial candidate limit and rejects outside users" do
    selected_company, selected_user = create_confirmation(
      company_name: "Late Client",
      company_domain: "late.example",
      user_name: "zz Selected Reader",
      email: "zz-selected-reader@example.com"
    )
    outside_company, outside_user = create_confirmation(
      company_name: "Outside Client",
      company_domain: "outside.example",
      user_name: "Outside Reader",
      email: "outside-reader@example.com",
      target_document: other_document
    )

    Admin::ReadConfirmationsController::FILTER_CANDIDATE_LIMIT.times do |index|
      create_confirmation(
        company_name: "Early Client #{index}",
        company_domain: "early-#{index}.example",
        user_name: "Early Reader #{index}",
        email: format("early-%02d@example.com", index)
      )
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, company_id: selected_company.id, user_id: selected_user.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Late Client")
    expect(response.body).to include("zz Selected Reader / zz-selected-reader@example.com")
    expect(response.body).to include(company_search_admin_read_confirmations_path(format: :json, project_id: project.id))
    expect(response.body).to include(user_search_admin_read_confirmations_path(format: :json, project_id: project.id, company_id: selected_company.id))
    expect(response.body).to include("候補最大#{Admin::ReadConfirmationsController::FILTER_SEARCH_LIMIT}件")

    get selected_user_admin_read_confirmations_path(format: :json), params: { project_id: project.id, company_id: outside_company.id, id: outside_user.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end
end
