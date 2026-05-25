require "rails_helper"

RSpec.describe "admin webhook endpoints source" do
  let(:index_source) { Rails.root.join("app/views/admin/webhook_endpoints/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/webhook_endpoints_helper.rb").read }

  it "wires both admin tables to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('data-rails-table-preferences-column-key="name"')
      expect(index_source).to include('data-rails-table-preferences-column-key="target_url"')
      expect(index_source).to include('data-rails-table-preferences-column-key="event_types"')
      expect(index_source).to include('data-rails-table-preferences-column-key="active"')
      expect(index_source).to include('data-rails-table-preferences-column-key="actions"')
      expect(index_source).to include('data-rails-table-preferences-column-key="created_at"')
      expect(index_source).to include('data-rails-table-preferences-column-key="endpoint"')
      expect(index_source).to include('data-rails-table-preferences-column-key="event_type"')
      expect(index_source).to include('data-rails-table-preferences-column-key="status"')
      expect(index_source).to include('data-rails-table-preferences-column-key="response_status"')
      expect(index_source).to include('data-rails-table-preferences-column-key="error_message"')
      expect(index_source).to include("webhook_endpoint_status_label(endpoint)")
      expect(index_source).to include("webhook_delivery_status_label(delivery)")
      expect(index_source).to include("endpoint.normalized_event_types.each do |event_type|")
    end
  end

  it "defines helper metadata and status labels for both tables" do
    aggregate_failures do
      expect(helper_source).to include("def webhook_endpoint_table_columns")
      expect(helper_source).to include("def webhook_delivery_table_columns")
      expect(helper_source).to include("table_preferences_column(:name")
      expect(helper_source).to include("table_preferences_column(:event_types")
      expect(helper_source).to include("table_preferences_column(:created_at")
      expect(helper_source).to include("table_preferences_column(:endpoint")
      expect(helper_source).to include("table_preferences_column(:status")
      expect(helper_source).to include("table_preferences_column(:error_message")
      expect(helper_source).to include("def webhook_endpoint_status_label(endpoint)")
      expect(helper_source).to include('endpoint.active? ? "有効" : "停止"')
      expect(helper_source).to include("def webhook_delivery_status_label(delivery)")
      expect(helper_source).to include('when "failed"')
      expect(helper_source).to include('"送信待ち"')
    end
  end
end
