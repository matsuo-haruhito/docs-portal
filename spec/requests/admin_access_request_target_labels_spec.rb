require "rails_helper"

RSpec.describe "Admin access request target labels", type: :request do
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

  it "uses the same localized requestable type label in the target cell as the filter summary" do
    document_file = create(:document_file, document_version: create(:document_version, document:), file_name: "manual.pdf")
    create(:access_request, requester:, requestable: document_file, requested_access_level: :download, reason: "Need attachment")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { requestable_type: "DocumentFile" }

    row = parsed_html.css("tbody tr").find { |node| node.text.include?("Need attachment") }
    target_cell = row.at_css(%(td[data-rails-table-preferences-column-key="target"]))

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("対象種別: 添付ファイル")
    expect(target_cell.text.squish).to include("添付ファイル")
    expect(target_cell.text.squish).to include("manual.pdf")
    expect(target_cell.text.squish).not_to include("DocumentFile")
  end
end
