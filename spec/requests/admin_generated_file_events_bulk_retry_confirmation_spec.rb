require "rails_helper"

RSpec.describe "Admin generated file event bulk retry confirmation", type: :request do
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

  describe "GET /admin/generated_file_events" do
    it "adds a browser confirmation with the current failed target count and dispatch limit" do
      sign_in_as(admin_user)
      create_event!(path: "docs/failed.yml", status: :failed)

      get admin_generated_file_events_path(status: "failed")

      expect(response).to have_http_status(:ok)
      form = bulk_retry_form(status: "failed")
      expect(form).to be_present
      expect(form["data-turbo-confirm"]).to include("現在の条件で今回再投入する失敗イベント 1 件")
      expect(form["data-turbo-confirm"]).to include("古い順に最大100件")
      expect(form["data-turbo-confirm"]).to include("現在の条件を確認してから実行してください")
      expect(bulk_retry_button(status: "failed")["disabled"]).to be_nil
    end

    it "keeps zero-target bulk retry disabled without a confirmation attribute" do
      sign_in_as(admin_user)
      create_event!(path: "docs/processed.yml", status: :processed)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      form = bulk_retry_form
      expect(form).to be_present
      expect(form["data-turbo-confirm"]).to be_nil
      expect(bulk_retry_button["disabled"]).to eq("disabled")
      expect(response.body).to include("今回の一括再投入対象: 0 件")
      expect(response.body).to include("対象がないため一括再投入できません。")
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
