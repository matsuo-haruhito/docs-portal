require "rails_helper"

RSpec.describe DocumentDeliveryLog, type: :model do
  it "normalizes recipient address fields" do
    log = build(
      :document_delivery_log,
      to_addresses: " CLIENT@example.com;client@example.com\nother@example.com ",
      cc_addresses: " CC@example.com ",
      bcc_addresses: ""
    )

    log.validate

    expect(log.to_addresses).to eq("client@example.com, other@example.com")
    expect(log.cc_addresses).to eq("cc@example.com")
    expect(log.bcc_addresses).to be_nil
    expect(log.recipients).to eq(["client@example.com", "other@example.com"])
  end

  it "uses public_id for routes" do
    log = create(:document_delivery_log)

    expect(log.to_param).to eq(log.public_id)
  end

  it "requires delivery content" do
    log = build(:document_delivery_log, to_addresses: "", subject: "", body: "")

    expect(log).not_to be_valid
    expect(log.errors[:to_addresses]).to be_present
    expect(log.errors[:subject]).to be_present
    expect(log.errors[:body]).to be_present
  end

  it "requires a document or document set target" do
    log = build(:document_delivery_log, document: nil, document_set: nil)

    expect(log).not_to be_valid
    expect(log.errors[:base]).to be_present
  end
end
