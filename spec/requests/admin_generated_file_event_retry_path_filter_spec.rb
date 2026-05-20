require "rails_helper"

RSpec.describe "Admin generated file event retry path filter", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "normalizes backslash path filters when retrying failed events" do
    sign_in_as(admin_user)
    matched = create(:generated_file_event, path: "docs/source.yml", status: :failed, error_message: "boom")
    unmatched = create(:generated_file_event, path: "docs/other.yml", status: :failed, error_message: "boom")
    allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

    post retry_failed_admin_generated_file_events_path(path: "docs\\source.yml")

    expect(response).to redirect_to(admin_generated_file_events_path(path: "docs\\source.yml"))
    expect(matched.reload).to be_pending
    expect(matched.error_message).to be_nil
    expect(unmatched.reload).to be_failed
    expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
  end
end
