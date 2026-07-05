require "rails_helper"

RSpec.describe "Admin generated file event detail link accessibility", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "adds short row context to each action-column detail link" do
    sign_in_as(admin_user)
    failed_event = create_event!(
      path: "docs/secret/source.yml",
      operation: "update",
      status: :failed,
      error_message: "token-like private path should stay out"
    )
    pending_event = create_event!(
      path: "docs/another/private.yml",
      operation: "create",
      status: :pending,
      error_message: "metadata should stay out"
    )

    get admin_generated_file_events_path(status: "failed", page: 1)

    expect(response).to have_http_status(:ok)
    detail_links = parsed_html.css('a[href]').select { |link| link.text.squish == "詳細" }
    labels = detail_links.map { |link| link["aria-label"] }

    expect(labels).to contain_exactly(
      a_string_including(failed_event.public_id),
      a_string_including(pending_event.public_id)
    )
    expect(labels.uniq.size).to eq(labels.size)
    expect(labels).to all(include("の詳細を開く"))
    expect(labels.join(" ")).not_to include("docs/secret/source.yml")
    expect(labels.join(" ")).not_to include("private.yml")
    expect(labels.join(" ")).not_to include("token-like")
    detail_links.each do |link|
      expect(link["title"]).to eq(link["aria-label"])
      expect(link["href"]).to include("return_to=")
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
