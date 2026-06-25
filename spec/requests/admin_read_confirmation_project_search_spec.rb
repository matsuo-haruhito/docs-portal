require "rails_helper"

RSpec.describe "Admin read confirmation project search", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "READ", name: "Read Project") }

  def json_body
    JSON.parse(response.body)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "returns bounded project options matching project code or name" do
    matching_by_code = create(:project, code: "READ-ALPHA", name: "Alpha")
    matching_by_name = create(:project, code: "BETA", name: "Read Beta")
    create(:project, code: "OTHER", name: "Archive")

    sign_in_as(admin_user)

    get project_search_admin_read_confirmations_path(format: :json, q: "read")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")

    options = json_body.fetch("options")
    expect(options).to contain_exactly(
      { "value" => matching_by_code.id, "text" => "READ-ALPHA / Alpha" },
      { "value" => matching_by_name.id, "text" => "BETA / Read Beta" }
    )
  end

  it "limits blank project search and truncates long queries" do
    first_project = create(:project, code: "P000", name: "First")
    25.times { |index| create(:project, code: format("P%03d", index + 1), name: "Project #{index + 1}") }
    matching_project = create(:project, code: "LONG", name: "#{'a' * Admin::ReadConfirmationsController::PROJECT_SEARCH_QUERY_MAX_LENGTH} target")
    create(:project, code: "MISS", name: "target only")

    sign_in_as(admin_user)

    get project_search_admin_read_confirmations_path(format: :json)

    blank_options = json_body.fetch("options")
    expect(blank_options.size).to eq(Admin::ReadConfirmationsController::PROJECT_SEARCH_LIMIT)
    expect(blank_options).to include(
      { "value" => first_project.id, "text" => "P000 / First" }
    )

    get project_search_admin_read_confirmations_path(
      format: :json,
      q: "#{'a' * Admin::ReadConfirmationsController::PROJECT_SEARCH_QUERY_MAX_LENGTH}should-not-match"
    )

    options = json_body.fetch("options")
    expect(options).to contain_exactly(
      { "value" => matching_project.id, "text" => "LONG / #{matching_project.name}" }
    )
  end

  it "returns the selected project option even when it is outside the search limit" do
    25.times { |index| create(:project, code: format("P%03d", index), name: "Project #{index}") }
    selected = create(:project, code: "ZZZ", name: "Selected Later")

    sign_in_as(admin_user)

    get selected_project_admin_read_confirmations_path(format: :json, id: selected.id)

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to eq(
      "value" => selected.id,
      "text" => "ZZZ / Selected Later"
    )
  end

  it "returns nil for a missing selected project without leaking metadata" do
    sign_in_as(admin_user)

    get selected_project_admin_read_confirmations_path(format: :json, id: "999999")

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders the remote project selector without changing existing filter and CSV links" do
    company = create(:company, name: "Client A")
    user = create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com")
    document = create(:document, project:, title: "Manual", slug: "manual")
    create(:read_confirmation, document:, user:, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: "manual",
      company_id: company.id,
      user_id: user.id,
      from: "2026-05-01",
      to: "2026-05-03"
    )

    expect(response).to have_http_status(:ok)

    project_selector = parsed_html.at_css("[name='project_id']")
    expect(project_selector).to be_present
    expect(response.body).to include(project_search_admin_read_confirmations_path(format: :json))
    expect(response.body).to include(selected_project_admin_read_confirmations_path(format: :json))
    expect(response.body).to include(Admin::ReadConfirmationsController::PROJECT_SEARCH_LIMIT.to_s)
    expect(response.body).to include("READ / Read Project")

    csv_link = parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
    usage_report_link = parsed_html.css("a").find { |link| link.text.squish == "文書利用状況へ戻る" }

    expect(csv_link["href"]).to include("project_id=#{project.id}")
    expect(csv_link["href"]).to include("document_slug=manual")
    expect(csv_link["href"]).to include("company_id=#{company.id}")
    expect(csv_link["href"]).to include("user_id=#{user.id}")
    expect(csv_link["href"]).to include("from=2026-05-01")
    expect(csv_link["href"]).to include("to=2026-05-03")
    expect(csv_link["href"]).to include("format=csv")
    expect(usage_report_link["href"]).to include("project_id=#{project.id}")
    expect(usage_report_link["href"]).to include("q=manual")
  end

  it "keeps invalid project ids from showing rows or exporting all confirmations" do
    document = create(:document, project:, title: "Manual", slug: "manual")
    create(:read_confirmation, document:, user: create(:user, :external, name: "Reader One"))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: "999999")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("案件を選択すると既読確認の内訳を表示します。")
    expect(parsed_html.text.squish).not_to include("Manual")
    expect(parsed_html.text.squish).not_to include("Reader One")

    get admin_read_confirmations_path(project_id: "999999", format: :csv)

    expect(response).to redirect_to(admin_read_confirmations_path)
  end

  it "forbids external users from project search endpoints" do
    sign_in_as(external_user)

    get project_search_admin_read_confirmations_path(format: :json, q: "read")
    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_read_confirmations_path(format: :json, id: project.id)
    expect(response).to have_http_status(:forbidden)
  end
end
