require "rails_helper"

RSpec.describe ExternalFolderSync::WebhookEventResultRecorder do
  it "records a terminal result only for the processing event owned by that run" do
    source = create(:external_folder_sync_source)
    run = source.external_folder_sync_runs.create!(
      mode: :apply,
      status: :completed,
      enqueued_at: 2.minutes.ago,
      started_at: 1.minute.ago,
      finished_at: Time.current
    )
    event = create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: run,
      status: :processing
    )

    expect(described_class.call(event:, run:)).to be(true)

    expect(event.reload).to be_completed
    expect(event.payload_json.fetch("sync_run").fetch("public_id")).to eq(run.public_id)
  end

  it "does not let an old terminal run overwrite a replacement event" do
    source = create(:external_folder_sync_source)
    old_run = source.external_folder_sync_runs.create!(
      mode: :apply,
      status: :failed,
      enqueued_at: 3.minutes.ago,
      started_at: 2.minutes.ago,
      finished_at: 1.minute.ago,
      error_message: "old failure"
    )
    replacement = source.external_folder_sync_runs.create!(
      mode: :apply,
      status: :running,
      enqueued_at: 1.minute.ago,
      started_at: Time.current,
      heartbeat_at: Time.current
    )
    event = create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: replacement,
      status: :processing
    )
    original_attributes = event.attributes

    expect(described_class.call(event:, run: old_run)).to be(false)

    expect(event.reload.attributes).to eq(original_attributes)
  end
end
