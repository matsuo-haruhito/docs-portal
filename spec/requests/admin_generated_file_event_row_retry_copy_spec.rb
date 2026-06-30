require "rails_helper"

RSpec.describe "Admin generated file event row retry copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "distinguishes row retry from bulk retry in visible and accessible copy" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/failed.yml", status: :failed)

    get admin_generated_file_events_path(status: "failed")

    expect(response).to have_http_status(:ok)

    retry_panel = parsed_html.at_css("div.rounded.border.border-red-100")
    expect(retry_panel.text.squish).to include("失敗分を一括再投入")
    expect(retry_panel.text.squish).to include("現在の条件に一致する失敗イベント")

    row_retry_button = parsed_html.at_css(%(form[action="#{retry_dispatch_admin_generated_file_event_path(event.public_id)}"] button[type="submit"]))
    expect(row_retry_button).to be_present
    expect(row_retry_button.text.squish).to eq("この1件を再投入")
    expect(row_retry_button["title"]).to eq("#{event.public_id} 1件を再投入キューに投入（一括再投入ではありません）")
    expect(row_retry_button["aria-label"]).to eq("#{event.public_id} 1件を再投入キューに投入（一括再投入ではありません）")
    expect(response.body).not_to include("このイベントを再投入")
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
