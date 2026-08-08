require "rails_helper"

RSpec.describe ExternalMasterSyncMapping, type: :model do
  it "enforces the resource and polymorphic target pairing in the database" do
    company = create(:company)
    mapping = create_mapping(company)

    expect do
      described_class.where(id: mapping.id).update_all(
        resource_type: "company",
        sync_target_type: "Project"
      )
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "enforces supported receipt resource types in the database" do
    receipt = MasterSyncReceipt.create!(
      idempotency_key: SecureRandom.uuid,
      request_digest: "a" * 64,
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-1",
      response_status: 200,
      response_body: {"status" => "applied"},
      completed_at: Time.current
    )

    expect do
      MasterSyncReceipt.where(id: receipt.id).update_all(resource_type: "unknown")
    end.to raise_error(ActiveRecord::StatementInvalid)
  end

  def create_mapping(company)
    described_class.create!(
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-constraint",
      sync_target: company,
      source_updated_at: Time.current,
      source_attributes: {"name" => company.name}
    )
  end
end
