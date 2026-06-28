require "rails_helper"

RSpec.describe "Admin generated file event pagination bounds", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  it "clamps out-of-range pages to the last page while preserving filters" do
    sign_in_as(admin_user)
    newest = create_event!(path: "docs/newest.yml", status: :failed, created_at: Time.zone.parse("2026-05-12 12:00:00"))
    middle = create_event!(path: "docs/middle.yml", status: :failed, created_at: Time.zone.parse("2026-05-11 12:00:00"))
    oldest = create_event!(path: "docs/oldest.yml", status: :failed, created_at: Time.zone.parse("2026-05-10 12:00:00"))
    pending = create_event!(path: "docs/pending.yml", status: :pending, created_at: Time.zone.parse("2026-05-09 12:00:00"))

    get admin_generated_file_events_path(status: "failed", page: 999, per_page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(oldest.public_id)
    expect(response.body).not_to include(newest.public_id)
    expect(response.body).not_to include(middle.public_id)
    expect(response.body).not_to include(pending.public_id)
    expect(page_text).to include("全 3 件 / 2 / 2 ページ")
    expect(page_text).not_to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(link_hrefs).to include(admin_generated_file_events_path(status: "failed", page: 1, per_page: 2))
  end

  it "keeps invalid and non-positive pages on the first page" do
    sign_in_as(admin_user)
    newest = create_event!(path: "docs/newest.yml", created_at: Time.zone.parse("2026-05-12 12:00:00"))
    older = create_event!(path: "docs/older.yml", created_at: Time.zone.parse("2026-05-11 12:00:00"))

    get admin_generated_file_events_path(page: 0, per_page: 1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(newest.public_id)
    expect(response.body).not_to include(older.public_id)
    expect(page_text).to include("全 2 件 / 1 / 2 ページ")

    get admin_generated_file_events_path(page: "bad", per_page: 1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(newest.public_id)
    expect(response.body).not_to include(older.public_id)
    expect(page_text).to include("全 2 件 / 1 / 2 ページ")
  end

  private

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
