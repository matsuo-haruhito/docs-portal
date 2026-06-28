require "rails_helper"

RSpec.describe "Admin generated file event source filter cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_events" do
    it "shows that event source filtering uses exact saved values" do
      sign_in_as(admin_user)
      create_event!(event_source: "manual_document_upload")

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("保存値と完全一致する発生元だけに絞り込みます。")
      expect(response.body).to include("短い断片で探す場合は「イベントID / パス / エラー」を使ってください。")
    end

    it "filters event source by exact match instead of fragments" do
      sign_in_as(admin_user)
      matched = create_event!(path: "docs/manual-source.yml", event_source: "manual_document_upload")
      unmatched = create_event!(path: "docs/artifact-source.yml", event_source: "artifact_import")

      get admin_generated_file_events_path(event_source: "manual_document_upload")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched.public_id)

      get admin_generated_file_events_path(event_source: "manual")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(matched.public_id)
      expect(response.body).not_to include(unmatched.public_id)
      expect(response.body).to include("検索条件に一致する生成ファイルイベントはありません。")
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
