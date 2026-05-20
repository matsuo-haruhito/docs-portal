require "rails_helper"

RSpec.describe "Admin generated file event retry limit", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "bulk retries at most 100 failed events" do
    sign_in_as(admin_user)
    failed_events = Array.new(101) do |index|
      create(:generated_file_event, path: "docs/failed-#{index}.yml", status: :failed, error_message: "boom", created_at: index.minutes.ago)
    end
    allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

    post retry_failed_admin_generated_file_events_path

    retried_count = failed_events.count { _1.reload.pending? }
    failed_count = failed_events.count { _1.reload.failed? }
    expect(response).to redirect_to(admin_generated_file_events_path)
    expect(retried_count).to eq(100)
    expect(failed_count).to eq(1)
    expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
  end
end
