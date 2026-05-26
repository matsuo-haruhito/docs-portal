require "rails_helper"

RSpec.describe "admin external integration project selectors source" do
  let(:external_folder_sync_source_form) do
    Rails.root.join("app/views/admin/external_folder_sync_sources/_form.html.slim").read
  end

  let(:external_folder_sync_source_show) do
    Rails.root.join("app/views/admin/external_folder_sync_sources/show.html.slim").read
  end

  let(:external_folder_sync_sources_index) do
    Rails.root.join("app/views/admin/external_folder_sync_sources/index.html.slim").read
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

  it "keeps provider-aware guidance for the external folder sync source entry" do
    aggregate_failures do
      expect(external_folder_sync_source_form).to include("h2 外部フォルダを取り込む")
      expect(external_folder_sync_source_form).to include("h3 Google Drive から始める")
      expect(external_folder_sync_source_form).to include("h3 SharePoint / OneDrive を準備する")
      expect(external_folder_sync_source_form).to include("admin_microsoft_graph_connections_path")
      expect(external_folder_sync_source_form).to include("| 外部フォルダURL")
      expect(external_folder_sync_source_form).not_to include("h2 Google Driveフォルダを取り込む")
      expect(external_folder_sync_source_form).not_to include("| Google DriveフォルダURL")
    end
  end

  it "keeps provider-aware guidance for the external folder sync source detail" do
    aggregate_failures do
      expect(external_folder_sync_source_show).to include("provider_label = external_folder_sync_source_provider_label(@external_folder_sync_source)")
      expect(external_folder_sync_source_show).to include("google_drive_source = @external_folder_sync_source.google_drive?")
      expect(external_folder_sync_source_show).to include('apply_confirm_message = "#{provider_label} からドキュメントポータルへ同期します。競合・重複警告がある場合は自動停止します。よろしいですか？"')
      expect(external_folder_sync_source_show).to include("dt 外部フォルダURL")
      expect(external_folder_sync_source_show).to include("dt 外部フォルダID")
      expect(external_folder_sync_source_show).to include("dt 同期カーソル")
      expect(external_folder_sync_source_show).to include("h2 変更通知とイベント受信")
      expect(external_folder_sync_source_show).not_to include("dt Google DriveフォルダURL")
      expect(external_folder_sync_source_show).not_to include("dt Google DriveフォルダID")
      expect(external_folder_sync_source_show).not_to include("dt Google Driveカーソル")
    end
  end

  it "uses a provider-neutral folder id header on the external folder sync index" do
    aggregate_failures do
      expect(external_folder_sync_sources_index).to include("th 外部フォルダID")
      expect(external_folder_sync_sources_index).not_to include("th Google DriveフォルダID")
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