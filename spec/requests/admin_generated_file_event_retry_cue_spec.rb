require "rails_helper"

RSpec.describe "Admin generated file event retry cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "explains that the detail retry action affects only the current event" do
    sign_in_as(admin_user)
    event = create_event!(
      path: "docs/source.yml",
      status: :failed,
      processed_at: 30.minutes.ago,
      error_message: "boom"
    )

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("このイベントを再投入")
    expect(response.body).to include("このイベント1件だけを再投入キューへ戻します。")
    expect(response.body).to include("状態は未処理に戻り、エラーと処理日時は再投入向けにクリアされます。")
    expect(response.body).to include(%(aria-label="#{event.public_id} を再投入キューに投入"))
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
