require "rails_helper"

RSpec.describe "Admin generated file event action grouping", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  def bulk_retry_button(filters = {})
    parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_events_path(filters)}"] button[type="submit"]))
  end

  it "separates bulk redispatch execution from status filter links" do
    sign_in_as(admin_user)
    create_event!(path: "docs/failed.yml", status: :failed)

    get admin_generated_file_events_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("実行操作")
    expect(response.body).to include("表示フィルタ")
    expect(response.body).to include("再投入は表示フィルタではなく、現在の条件に一致する失敗イベントを再投入する操作です。")
    expect(response.body).to include("今回の一括再投入対象: 1 件")
    expect(response.body).to include("現在の条件で今回再投入する失敗イベントを、古い順に最大100件まで処理します。")
    expect(bulk_retry_button(status: "failed")).to be_present
    expect(bulk_retry_button(status: "failed")["disabled"]).to be_nil
    expect(link_hrefs).to include(admin_generated_file_events_path)
    expect(link_hrefs).to include(admin_generated_file_events_path(status: "pending"))
    expect(link_hrefs).to include(admin_generated_file_events_path(status: "processed"))
  end

  it "keeps the disabled reason close to the bulk redispatch action" do
    sign_in_as(admin_user)
    create_event!(path: "docs/processed.yml", status: :processed)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("実行操作")
    expect(response.body).to include("今回の一括再投入対象: 0 件")
    expect(response.body).to include("対象がないため一括再投入できません。")
    expect(bulk_retry_button).to be_present
    expect(bulk_retry_button["disabled"]).to eq("disabled")
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
