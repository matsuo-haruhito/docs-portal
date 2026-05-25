require "rails_helper"

RSpec.describe "admin external integration project selectors source" do
  let(:external_folder_sync_source_form) do
    Rails.root.join("app/views/admin/external_folder_sync_sources/_form.html.slim").read
  end

  let(:microsoft_graph_connection_form) do
    Rails.root.join("app/views/admin/microsoft_graph_connections/_form.html.slim").read
  end

  it "uses rails fields kit for the external folder sync source project selector" do
    aggregate_failures do
      expect(external_folder_sync_source_form).to include("= form.rfk_select :project_id,")
      expect(external_folder_sync_source_form).to include("collection: @projects")
      expect(external_folder_sync_source_form).to include("collection_value_method: :id")
      expect(external_folder_sync_source_form).to include("collection_label_method: :name")
      expect(external_folder_sync_source_form).to include('label: "対象案件"')
      expect(external_folder_sync_source_form).not_to include("collection_select :project_id")
    end
  end

  it "uses rails fields kit for the microsoft graph connection project selector" do
    aggregate_failures do
      expect(microsoft_graph_connection_form).to include("= form.rfk_select :project_id,")
      expect(microsoft_graph_connection_form).to include("collection: @projects")
      expect(microsoft_graph_connection_form).to include("collection_value_method: :id")
      expect(microsoft_graph_connection_form).to include("collection_label_method: :name")
      expect(microsoft_graph_connection_form).to include('label: "案件"')
      expect(microsoft_graph_connection_form).not_to include("collection_select :project_id")
    end
  end
end
