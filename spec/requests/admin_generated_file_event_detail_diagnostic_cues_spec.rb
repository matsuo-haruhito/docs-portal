require "rails_helper"

RSpec.describe "Admin generated file event detail diagnostic cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows diagnostic cues and masked previews for event errors and metadata" do
    sign_in_as(admin_user)
    event = create_event!(
      path: "docs/source.yml",
      status: :failed,
      error_message: "Authorization: Bearer raw-token token=secret /home/app/private/payload.json",
      metadata: {
        "actor_id" => 1,
        "token" => "metadata-secret",
        "artifact_path" => "/home/app/private/artifact.json"
      }
    )

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("エラーは再投入前の状態確認に使う診断用プレビューです。")
    expect(page_text).to include("メタデータはイベント補助情報の診断用プレビューです。")
    expect(response.body).to include("Authorization: Bearer [FILTERED]")
    expect(response.body).to include("token=[FILTERED]")
    expect(response.body).to include("actor_id")
    expect(response.body).to include("[FILTERED]")
    expect(response.body).to include("このイベントを再投入")
    expect(response.body).not_to include("raw-token")
    expect(response.body).not_to include("token=secret")
    expect(response.body).not_to include("metadata-secret")
    expect(response.body).not_to include("/home/app/private")
  end

  it "shows an explicit empty metadata state without changing retry context" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml", status: :pending, metadata: {})

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("概要")
    expect(page_text).to include("メタデータはイベント補助情報の診断用プレビューです。")
    expect(page_text).to include("このイベントに補助メタデータはありません。")
    expect(response.body).to include("このイベントを再投入")
    expect(response.body).to include("このイベント1件だけを再投入キューへ戻します。")
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
