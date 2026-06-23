require "rails_helper"

RSpec.describe "Admin generated file event bulk retry confirm", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def bulk_retry_form(filters = {})
    parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_events_path(filters)}"]))
  end

  def bulk_retry_button(filters = {})
    bulk_retry_form(filters)&.at_css(%(button[type="submit"]))
  end

  it "confirms the filtered bulk redispatch target before posting" do
    sign_in_as(admin_user)
    create_event!(
      path: "storage/document_files/source.yml",
      status: :failed,
      event_source: "manual_document_upload",
      error_message: "source failed",
      scheduled_at: Time.zone.parse("2026-05-10 12:00:00")
    )
    filters = {
      status: "failed",
      event_source: "manual_document_upload",
      path: "document_files",
      scheduled_from: "2026-05-10",
      scheduled_to: "2026-05-10",
      q: "source"
    }

    get admin_generated_file_events_path(filters)

    expect(response).to have_http_status(:ok)
    expect(bulk_retry_button(filters)["disabled"]).to be_nil
    confirm_message = bulk_retry_form(filters)["data-turbo-confirm"]
    expect(confirm_message).to include("現在の条件に一致する失敗イベント 1 件")
    expect(confirm_message).to include("古い順に最大100件")
    expect(confirm_message).to include("現在の条件を確認してから実行してください")
  end

  it "keeps the empty bulk redispatch state disabled without an executable confirm" do
    sign_in_as(admin_user)
    create_event!(path: "docs/processed.yml", status: :processed)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の条件で再投入対象: 0 件")
    expect(response.body).to include("対象がないため一括再投入できません。")
    expect(bulk_retry_button["disabled"]).to eq("disabled")
    expect(bulk_retry_form["data-turbo-confirm"]).to be_nil
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
