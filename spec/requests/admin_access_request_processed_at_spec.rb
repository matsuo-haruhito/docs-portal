require "rails_helper"

RSpec.describe "Admin access request processed timestamps", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def table_headers
    parsed_html.css("thead th").to_h do |header|
      [header["data-rails-table-preferences-column-key"], header.text.squish]
    end
  end

  def row_for(reason)
    parsed_html.css("tbody tr").find { |row| row.text.include?(reason) }
  end

  def cell_text(row, column_key)
    row.at_css("td[data-rails-table-preferences-column-key='#{column_key}']").text.squish
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "separates requested and processed timestamps for every access request state" do
    create(:access_request,
      requester:,
      requestable: document,
      status: :pending,
      created_at: Time.zone.local(2026, 5, 1, 9, 0, 0),
      reason: "Pending timestamp")
    create(:access_request,
      requester:,
      requestable: document,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 2, 10, 15, 0),
      created_at: Time.zone.local(2026, 5, 1, 10, 0, 0),
      reason: "Approved timestamp")
    create(:access_request,
      requester:,
      requestable: project,
      status: :rejected,
      approver: admin_user,
      rejected_at: Time.zone.local(2026, 5, 3, 11, 30, 0),
      rejection_reason: "No access",
      created_at: Time.zone.local(2026, 5, 1, 11, 0, 0),
      reason: "Rejected timestamp")
    create(:access_request,
      requester:,
      requestable: project,
      status: :cancelled,
      cancelled_at: Time.zone.local(2026, 5, 4, 12, 45, 0),
      created_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Cancelled timestamp")

    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(table_headers).to include(
      "created_at" => "申請日時",
      "processed_at" => "処理日時"
    )

    pending_row = row_for("Pending timestamp")
    approved_row = row_for("Approved timestamp")
    rejected_row = row_for("Rejected timestamp")
    cancelled_row = row_for("Cancelled timestamp")

    expect(cell_text(pending_row, "created_at")).to eq("2026-05-01 09:00")
    expect(cell_text(pending_row, "processed_at")).to eq("-")

    expect(cell_text(approved_row, "created_at")).to eq("2026-05-01 10:00")
    expect(cell_text(approved_row, "processed_at")).to include("承認日時")
    expect(cell_text(approved_row, "processed_at")).to include("2026-05-02 10:15")

    expect(cell_text(rejected_row, "created_at")).to eq("2026-05-01 11:00")
    expect(cell_text(rejected_row, "processed_at")).to include("却下日時")
    expect(cell_text(rejected_row, "processed_at")).to include("2026-05-03 11:30")

    expect(cell_text(cancelled_row, "created_at")).to eq("2026-05-01 12:00")
    expect(cell_text(cancelled_row, "processed_at")).to include("取消日時")
    expect(cell_text(cancelled_row, "processed_at")).to include("2026-05-04 12:45")
  end
end
