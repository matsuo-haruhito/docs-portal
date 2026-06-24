require "rails_helper"

RSpec.describe "Admin generated file event status quick links", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def current_status_quick_links
    parsed_html.css(%(a[aria-current="page"])).select do |link|
      link.text.squish.in?(["すべて"] + GeneratedFileEvent.statuses.keys.map { generated_file_event_status_label(_1) })
    end
  end

  it "marks the all status quick link as current when no status filter is selected" do
    sign_in_as(admin_user)
    create_event!(status: :pending)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(current_status_quick_links.map { _1.text.squish }).to eq(["すべて"])
    expect(current_status_quick_links.first["href"]).to eq(admin_generated_file_events_path)
  end

  it "marks only the selected status quick link as current while preserving filters" do
    sign_in_as(admin_user)
    create_event!(path: "docs/failed.yml", status: :failed, error_message: "retry boom")
    filters = { status: "failed", path: "docs", q: "boom" }

    get admin_generated_file_events_path(filters)

    expect(response).to have_http_status(:ok)
    expect(current_status_quick_links.map { _1.text.squish }).to eq([generated_file_event_status_label("failed")])
    expect(current_status_quick_links.first["href"]).to eq(admin_generated_file_events_path(filters))
    all_status_link = parsed_html.css(%(a[href="#{admin_generated_file_events_path(filters.except(:status))}"])).find { _1.text.squish == "すべて" }
    expect(all_status_link).to be_present
    expect(all_status_link["aria-current"]).to be_nil
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
