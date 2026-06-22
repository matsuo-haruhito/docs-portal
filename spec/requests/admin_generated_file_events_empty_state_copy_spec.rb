require "rails_helper"

RSpec.describe "Admin generated file event empty state copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def clear_results_link
    parsed_html.css(%(a[href="#{admin_generated_file_events_path}"])).find do |link|
      link.text.squish == "すべての生成ファイルイベントを見る"
    end
  end

  it "shows scheduled date boundary cues without changing filter behavior" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("日付だけ指定すると、その日の00:00以降を含みます。")
    expect(page_text).to include("日付だけ指定すると、その日の23:59までを含みます。")
  end

  it "keeps the initial empty state separate from filtered empty results" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("生成ファイルイベントはまだありません。")
    expect(page_text).not_to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(clear_results_link).to be_nil
  end

  it "adds a clear path inside filtered empty results" do
    sign_in_as(admin_user)
    create_event!(path: "docs/generated.yml", status: :processed, error_message: "completed")

    get admin_generated_file_events_path(status: "failed", q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(page_text).to include("これは表示フィルタの結果です。")
    expect(page_text).to include("一括再投入対象の有無とは別に")
    expect(clear_results_link).to be_present
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
