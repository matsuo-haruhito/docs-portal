require "rails_helper"

RSpec.describe "Admin manual operations maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }

  around do |example|
    original_value = ENV["READ_ONLY_MAINTENANCE"]
    ENV["READ_ONLY_MAINTENANCE"] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete("READ_ONLY_MAINTENANCE")
    else
      ENV["READ_ONLY_MAINTENANCE"] = original_value
    end
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps generated file events readable but blocks single and bulk redispatch" do
      sign_in_as(admin_user)
      event = create_generated_file_event!(
        path: "docs/source.yml",
        status: :failed,
        scheduled_at: 1.hour.ago,
        processed_at: 30.minutes.ago,
        error_message: "boom"
      )
      bulk_event = create_generated_file_event!(
        path: "docs/bulk.yml",
        status: :failed,
        event_source: "manual_document_upload",
        scheduled_at: 2.hours.ago,
        processed_at: 20.minutes.ago,
        error_message: "bulk boom"
      )
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)
      return_to_path = admin_generated_file_events_path(status: "failed", page: 2, per_page: 25)

      get admin_generated_file_events_path(status: "failed")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)

      get admin_generated_file_event_path(event.public_id, return_to: return_to_path)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)

      post retry_dispatch_admin_generated_file_event_path(event.public_id, return_to: return_to_path)
      expect(response).to redirect_to(admin_generated_file_event_path(event.public_id, return_to: return_to_path))
      expect(flash[:alert]).to include("メンテナンス中のため生成ファイルイベントの再投入は停止しています")
      expect(GeneratedFileEventDispatchJob).not_to have_received(:perform_later)
      event.reload
      expect(event).to be_failed
      expect(event.error_message).to eq("boom")
      expect(event.processed_at).to be_present

      post retry_failed_admin_generated_file_events_path(event_source: "manual_document_upload")
      expect(response).to redirect_to(admin_generated_file_events_path(event_source: "manual_document_upload"))
      expect(flash[:alert]).to include("メンテナンス中のため生成ファイルイベントの再投入は停止しています")
      expect(GeneratedFileEventDispatchJob).not_to have_received(:perform_later)
      expect(bulk_event.reload).to be_failed
      expect(bulk_event.error_message).to eq("bulk boom")
    end

    it "keeps recurring job schedules readable but blocks definition sync and run requests" do
      sign_in_as(admin_user)
      schedule = create_schedule!(job_key: "maintenance_job", last_status: "failed")
      allow(RecurringJobDispatcherJob).to receive(:perform_now)
      allow(RecurringJobDispatcherJob).to receive(:perform_later)

      get admin_recurring_job_schedules_path(status: "failed")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("maintenance_job")

      get admin_recurring_job_schedule_path(schedule)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("maintenance_job")

      post sync_definitions_admin_recurring_job_schedules_path(status: "failed")
      expect(response).to redirect_to(admin_recurring_job_schedules_path(status: "failed"))
      expect(flash[:alert]).to include("メンテナンス中のため定期ジョブの定義同期・即時実行要求は停止しています")
      expect(RecurringJobDispatcherJob).not_to have_received(:perform_now)

      post request_run_admin_recurring_job_schedule_path(schedule)
      expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path))
      expect(flash[:alert]).to include("メンテナンス中のため定期ジョブの定義同期・即時実行要求は停止しています")
      expect(RecurringJobDispatcherJob).not_to have_received(:perform_later)
      expect(schedule.reload.run_requested_at).to be_nil
    end

    it "keeps webhook delivery evidence readable but blocks single and bulk redelivery" do
      sign_in_as(admin_user)
      event = create(:notification_event, event_type: :document_updated)
      endpoint = create(:webhook_endpoint, name: "Maintenance Hook", active: true)
      delivery = create(
        :webhook_delivery,
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: event.event_type,
        status: :failed,
        response_status: 500,
        error_message: "timeout"
      )
      allow(WebhookDeliveryDispatcher).to receive(:new)

      get admin_webhook_deliveries_path(status: "failed")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(delivery.public_id)

      get admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(delivery.public_id)

      get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("candidates", "current_filter")

      post retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed")
      expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
      expect(flash[:alert]).to include("メンテナンス中のためWebhook再送は停止しています")
      expect(WebhookDeliveryDispatcher).not_to have_received(:new)

      post retry_failed_admin_webhook_deliveries_path(delivery_status: "failed")
      expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
      expect(flash[:alert]).to include("メンテナンス中のためWebhook再送は停止しています")
      expect(WebhookDeliveryDispatcher).not_to have_received(:new)
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps recurring definition sync behavior available" do
      sign_in_as(admin_user)
      allow(RecurringJobDispatcherJob).to receive(:perform_now)

      post sync_definitions_admin_recurring_job_schedules_path

      expect(response).to redirect_to(admin_recurring_job_schedules_path)
      expect(flash[:notice]).to eq("定期ジョブ定義を同期しました。")
      expect(RecurringJobDispatcherJob).to have_received(:perform_now).once
    end
  end

  def create_generated_file_event!(attributes = {})
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

  def create_schedule!(attributes = {})
    defaults = {
      job_key: "sample_job",
      job_class: "SampleJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: []
    }

    RecurringJobSchedule.create!(defaults.merge(attributes))
  end
end
