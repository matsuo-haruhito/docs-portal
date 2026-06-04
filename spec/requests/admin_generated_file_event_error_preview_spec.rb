require "rails_helper"

RSpec.describe "Admin generated file event error previews", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  describe "GET /admin/generated_file_events" do
    it "shows a short error preview without raw sensitive fragments" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        error_message: "Upload failed Authorization: Bearer raw-access-token token=raw-secret-value at C:/Users/alice/customer-docs/source.yml because the generated file could not be written"
      )

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("[FILTERED]")
      expect(response.body).to include(admin_generated_file_event_path(event.public_id, return_to: admin_generated_file_events_path))
      expect(response.body).to include('data-rails-table-preferences-column-key="error_message"')
      expect(response.body).not_to include("raw-access-token")
      expect(response.body).not_to include("raw-secret-value")
      expect(response.body).not_to include("C:/Users/alice/customer-docs/source.yml")

      error_cell = parsed_html.at_css('td[data-rails-table-preferences-column-key="error_message"]')
      expect(error_cell).to be_present
      expect(error_cell["title"]).to be_nil
      expect(error_cell.text.squish).to include("[FILTERED]")
      expect(error_cell.text.squish.length).to be <= 120
    end

    it "keeps blank error messages as a compact empty marker" do
      sign_in_as(admin_user)
      create_event!(path: "docs/source.yml", status: :failed, error_message: nil)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      error_cell = parsed_html.at_css('td[data-rails-table-preferences-column-key="error_message"]')
      expect(error_cell.text.squish).to eq("-")
      expect(error_cell["title"]).to be_nil
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
