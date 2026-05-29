require "rails_helper"

RSpec.describe "Admin generated file event retry reset", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "clears previous processing state when retrying a failed event" do
    sign_in_as(admin_user)
    event = create(
      :generated_file_event,
      :failed,
      scheduled_at: 2.hours.ago,
      processed_at: 1.hour.ago,
      error_message: "boom"
    )
    allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

    post retry_dispatch_admin_generated_file_event_path(event.public_id)

    expect(response).to redirect_to(admin_generated_file_event_path(event.public_id, return_to: admin_generated_file_events_path))
    event.reload
    expect(event).to be_pending
    expect(event.scheduled_at).to be_within(5.seconds).of(Time.current)
    expect(event.processed_at).to be_nil
    expect(event.error_message).to be_nil
    expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
  end
end
