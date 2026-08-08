require "rails_helper"

RSpec.describe "Admin model browser association values", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def table_headers
    parsed_html.css("thead th").map { _1.text.squish }
  end

  def table_row_including(text)
    parsed_html.css("tbody tr").find { _1.text.squish.include?(text) }
  end

  it "shows a readable company label next to project company ids" do
    company = create(:company, name: "Client Alpha")
    project = create(:project, company:, code: "ASSOC4107", name: "Association Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects")

    expect(response).to have_http_status(:ok)

    row_text = table_row_including(project.code).text.squish
    expect(table_headers).to include("会社")
    expect(row_text).to include("Client Alpha（ID: #{company.id}）")
  end

  it "shows a readable user label next to project membership user ids" do
    project = create(:project, code: "MEMB4107", name: "Membership Project")
    user = create(:user, :external, name: "External Reviewer", email_address: "reviewer@example.com")
    membership = create(:project_membership, project:, user:)

    sign_in_as(admin_user)
    get admin_model_browser_model_path("project_memberships")

    expect(response).to have_http_status(:ok)

    row_text = table_row_including(membership.public_id).text.squish
    expect(table_headers).to include("ユーザー")
    expect(row_text).to include("External Reviewer（ID: #{user.id}）")
  end

  it "renders polymorphic association ids and master sync types with Japanese labels" do
    company = create(:company, name: "同期先会社")
    mapping = ExternalMasterSyncMapping.create!(
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-polymorphic",
      sync_target: company,
      source_updated_at: Time.current,
      source_attributes: {"name" => company.name}
    )

    sign_in_as(admin_user)
    get admin_model_browser_model_path("external_master_sync_mappings")

    expect(response).to have_http_status(:ok)
    expect(table_headers).to include("同期先ID")
    row_text = table_row_including(mapping.public_id).text.squish
    expect(row_text).to include("同期先会社（ID: #{company.id}）")
    expect(row_text).to include("会社")
    expect(row_text).not_to match(/\bcompany\b/)
    expect(row_text).not_to include("Company")
  end

  it "renders a missing polymorphic target without returning 500" do
    company = create(:company, name: "削除対象会社")
    mapping = ExternalMasterSyncMapping.create!(
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-missing-target",
      sync_target: company,
      source_updated_at: Time.current,
      source_attributes: {"name" => company.name}
    )
    target_id = company.id
    company.delete

    sign_in_as(admin_user)
    get admin_model_browser_model_path("external_master_sync_mappings")

    expect(response).to have_http_status(:ok)
    expect(table_row_including(mapping.public_id).text.squish).to include("参照先なし（ID: #{target_id}）")
  end

  it "renders receipt resource types with Japanese labels" do
    receipt = MasterSyncReceipt.create!(
      idempotency_key: SecureRandom.uuid,
      request_digest: "a" * 64,
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-receipt",
      response_status: 200,
      response_body: {"status" => "applied"},
      completed_at: Time.current
    )

    sign_in_as(admin_user)
    get admin_model_browser_model_path("master_sync_receipts")

    expect(response).to have_http_status(:ok)
    row_text = table_row_including(receipt.public_id).text.squish
    expect(row_text).to include("会社")
    expect(row_text).not_to match(/\bcompany\b/)
  end
end
