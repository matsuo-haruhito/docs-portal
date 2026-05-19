require "rails_helper"

RSpec.describe "Admin generated file events", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_events" do
    it "shows generated file events for admin users" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :pending)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイルイベント")
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("docs/source.yml")
    end

    it "filters by status" do
      sign_in_as(admin_user)
      pending_event = create_event!(path: "docs/pending.yml", status: :pending)
      failed_event = create_event!(path: "docs/failed.yml", status: :failed)

      get admin_generated_file_events_path(status: "failed")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(failed_event.public_id)
      expect(response.body).not_to include(pending_event.public_id)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_generated_file_events_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /admin/generated_file_events/:public_id" do
    it "shows event details" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        metadata: {"actor_id" => 1},
        error_message: "boom"
      )

      get admin_generated_file_event_path(event.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("docs/source.yml")
      expect(response.body).to include("boom")
      expect(response.body).to include("actor_id")
    end
  end

  describe "POST /admin/generated_file_events/:public_id/retry_dispatch" do
    it "resets event to pending and enqueues dispatch job" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        scheduled_at: 1.hour.ago,
        processed_at: 30.minutes.ago,
        error_message: "boom"
      )
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_dispatch_admin_generated_file_event_path(event.public_id)

      expect(response).to redirect_to(admin_generated_file_event_path(event.public_id))
      event.reload
      expect(event).to be_pending
      expect(event.scheduled_at).to be_within(5.seconds).of(Time.current)
      expect(event.processed_at).to be_nil
      expect(event.error_message).to be_nil
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later)
    end
  end

  def create_event!(attributes = {})
    path = attributes.fetch(:path, "docs/source.yml")
    operation = attributes.fetch(:operation, "update")
    event_source = attributes.fetch(:event_source, "spec")
    defaults = {
      event_key: GeneratedFileEvent.build_event_key(path:, operation:, event_source:),
      path: path,
      operation: operation,
      event_source: event_source,
      status: :pending,
      metadata: {},
      scheduled_at: 1.minute.from_now,
      last_seen_at: Time.current,
      occurrences_count: 1
    }
    GeneratedFileEvent.create!(defaults.merge(attributes))
  end
end
