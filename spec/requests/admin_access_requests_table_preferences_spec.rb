require "rails_helper"

RSpec.describe "Admin access request table preferences", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "renders stable column keys and keeps pending actions inside the table" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need manual download")

    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("アクセス申請一覧の表示設定")

    table = parsed_html.at_css("th[data-rails-table-preferences-column-key='created_at']")&.ancestors("table")&.first
    expect(table).to be_present

    column_keys = table.css("thead th").map { |node| node["data-rails-table-preferences-column-key"] }
    expect(column_keys).to eq(%w[
      created_at
      processed_at
      requester
      target
      requested_access_level
      status
      reason
      approver
      actions
    ])

    row = table.at_css("tbody tr")
    expect(row.css("td[data-rails-table-preferences-column-key]").map { |node| node["data-rails-table-preferences-column-key"] }).to eq(column_keys)
    expect(row.text.squish).to include("Need manual download")
    expect(row.css("form[action='#{admin_access_request_path(access_request)}']").size).to eq(2)
  end

  it "does not render the table preference editor when there are no access requests" do
    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css("th[data-rails-table-preferences-column-key='created_at']")).to be_nil
    expect(parsed_html.text.squish).not_to include("アクセス申請一覧の表示設定")
  end
end
