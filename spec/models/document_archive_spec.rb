require "rails_helper"

RSpec.describe Document, type: :model do
  let(:actor) { create(:user, :internal) }
  let(:document) { create(:document) }

  it "archives and restores with notification events" do
    expect do
      document.archive!(actor:, retention_until: Time.zone.parse("2026-12-31 00:00"))
    end.to change(NotificationEvent, :count).by(1)

    expect(document.reload.archived?).to eq(true)
    expect(document.archived_by_user).to eq(actor)

    expect do
      document.restore!(actor:)
    end.to change(NotificationEvent, :count).by(1)

    expect(document.reload.archived?).to eq(false)
  end
end
