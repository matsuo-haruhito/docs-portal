require "rails_helper"

RSpec.describe "Admin generated file event search bounds", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows max length and short-fragment cues on q and path inputs" do
    sign_in_as(admin_user)
    create_event!(path: "docs/source.yml")

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css('input[name="q"]')&.[]("maxlength")).to eq("100")
    expect(parsed_html.at_css('input[name="path"]')&.[]("maxlength")).to eq("100")
    expect(response.body).to include("最大100文字。イベントID、パス、エラーの短い断片で探します。")
    expect(response.body).to include("最大100文字。Windowsの区切り文字")
  end

  it "normalizes long q filters before combining them with existing filters" do
    sign_in_as(admin_user)
    normalized_query = "alpha beta " + ("x" * 89)
    long_query = "  alpha   beta #{"x" * 89} ignored tail  "
    matched = create_event!(
      path: "docs/matched.yml",
      status: :failed,
      event_source: "manual_document_upload",
      error_message: "prefix #{normalized_query} suffix"
    )
    unmatched_status = create_event!(
      path: "docs/unmatched-status.yml",
      status: :pending,
      event_source: "manual_document_upload",
      error_message: "prefix #{normalized_query} suffix"
    )
    unmatched_tail = create_event!(
      path: "docs/unmatched-tail.yml",
      status: :failed,
      event_source: "manual_document_upload",
      error_message: "ignored tail"
    )

    get admin_generated_file_events_path(status: "failed", event_source: "manual_document_upload", q: long_query)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matched.public_id)
    expect(response.body).not_to include(unmatched_status.public_id)
    expect(response.body).not_to include(unmatched_tail.public_id)
  end

  it "does not apply q when the filter is blank after squishing" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml", status: :pending)

    get admin_generated_file_events_path(q: "   ")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(event.public_id)
    expect(parsed_html.at_css('input[name="q"]')&.[]("value").to_s).to eq("")
  end

  it "normalizes long backslash path filters before applying the path condition" do
    sign_in_as(admin_user)
    normalized_path_filter = "storage/generated/" + ("a" * 82)
    long_path_filter = "  storage\\generated\\#{"a" * 82} ignored-tail  "
    matched = create_event!(path: "#{normalized_path_filter}/result.yml", status: :pending)
    unmatched_tail = create_event!(path: "storage/generated/ignored-tail/result.yml", status: :pending)

    get admin_generated_file_events_path(path: long_path_filter)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matched.public_id)
    expect(response.body).not_to include(unmatched_tail.public_id)
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
