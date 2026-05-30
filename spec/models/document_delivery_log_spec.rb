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

  it "normalizes separators, case, whitespace, and duplicate recipients" do
    log = build(
      :document_delivery_log,
      to_addresses: " Client@Example.com ; client@example.com, SECOND@example.com\n third@example.com ",
      cc_addresses: " CC@example.com;cc@example.com ",
      bcc_addresses: " BCC@example.com\nbackup@example.com "
    )

    expect(log).to be_valid
    expect(log.to_addresses).to eq("client@example.com, second@example.com, third@example.com")
    expect(log.cc_addresses).to eq("cc@example.com")
    expect(log.bcc_addresses).to eq("bcc@example.com, backup@example.com")
    expect(log.recipients).to eq(%w[client@example.com second@example.com third@example.com])
    expect(log.cc_recipients).to eq(%w[cc@example.com])
    expect(log.bcc_recipients).to eq(%w[bcc@example.com backup@example.com])
  end

  it "keeps blank cc and bcc addresses optional" do
    log = build(:document_delivery_log, to_addresses: "client@example.com", cc_addresses: "", bcc_addresses: nil)

    expect(log).to be_valid
    expect(log.cc_addresses).to be_nil
    expect(log.bcc_addresses).to be_nil
  end

  it "rejects invalid to address tokens after normalization" do
    log = build(:document_delivery_log, to_addresses: "client@example.com, missing-at-sign")

    expect(log).not_to be_valid
    expect(log.errors.added?(:to_addresses, :invalid)).to be(true)
  end

  it "rejects invalid optional cc and bcc address tokens when present" do
    log = build(
      :document_delivery_log,
      to_addresses: "client@example.com",
      cc_addresses: "cc@example.com, cc-invalid",
      bcc_addresses: "bcc-invalid"
    )

    expect(log).not_to be_valid
    expect(log.errors.added?(:cc_addresses, :invalid)).to be(true)
    expect(log.errors.added?(:bcc_addresses, :invalid)).to be(true)
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