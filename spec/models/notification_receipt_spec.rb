require "rails_helper"

RSpec.describe NotificationReceipt, type: :model do
  it "tracks unread and read states" do
    receipt = create(:notification_receipt)

    expect(receipt).not_to be_read
    expect(described_class.unread).to include(receipt)

    receipt.mark_as_read!

    expect(receipt).to be_read
    expect(described_class.read).to include(receipt)
  end

  it "does not allow duplicate receipts for the same event and user" do
    receipt = create(:notification_receipt)
    duplicate = build(:notification_receipt, notification_event: receipt.notification_event, user: receipt.user)

    expect(duplicate).not_to be_valid
  end
end
