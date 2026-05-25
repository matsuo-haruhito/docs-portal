require "rails_helper"

RSpec.describe "Admin generated file events index copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows Japanese labels while keeping status and operation filter values" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml", status: :failed, operation: "delete")

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("状態")
    expect(response.body).to include("操作種別")
    expect(response.body).to include("イベント発生元")
    expect(response.body).to include("パスを含む")
    expect(response.body).to include("イベントID")
    expect(response.body).to include("実行予定")
    expect(response.body).to include("処理完了")
    expect(response.body).to include("失敗")
    expect(response.body).to include("削除")
    expect(response.body).to include(%(value="failed"))
    expect(response.body).to include(%(value="delete"))
    expect(response.body).to include(event.public_id)
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
