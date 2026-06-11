# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection table preferences", type: :request do
  TABLE_COLUMN_KEYS = %w[
    project
    name
    graph_identifiers
    drive
    preview_folder
    status
    preview_usage
    actions
  ].freeze

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "renders the table preferences editor and stable Microsoft Graph connection columns" do
    admin = create(:user, :internal)
    project = create(:project, code: "GRAPH001", name: "Graph Project")
    connection = create(
      :microsoft_graph_connection,
      project: project,
      name: "Office preview",
      tenant_id: "tenant-alpha",
      client_id: "client-alpha",
      site_id: "site-alpha",
      drive_id: "drive-alpha",
      preview_folder_path: "Shared Documents/Office Preview",
      enabled: true
    )

    sign_in_as(admin)

    get admin_microsoft_graph_connections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Microsoft Graph接続一覧の表示設定")
    expect(response.body).to include("Graph Project")
    expect(response.body).to include(project.code)
    expect(response.body).to include(connection.name)
    expect(response.body).to include("主確認: Drive ID")
    expect(response.body).to include("主確認: プレビュー用フォルダ")
    expect(response.body).to include("previewで使用中")
    expect(response.body).to include("外部フォルダ同期設定を確認")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(response.body.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
    end
  end

  it "keeps the source contract for the table key, helper columns, and important default triage columns" do
    view_source = Rails.root.join("app/views/admin/microsoft_graph_connections/index.html.slim").read
    helper_source = Rails.root.join("app/helpers/admin/microsoft_graph_connections_helper.rb").read

    expect(view_source).to include("- table_key = :admin_microsoft_graph_connections")
    expect(view_source).to include("microsoft_graph_connection_table_columns")
    expect(view_source).to include("rails_table_preference_settings(table_key: table_key)")
    expect(view_source).to include('title: "Microsoft Graph接続一覧の表示設定"')
    expect(view_source).to include("table_preferences_editor(table_key: table_key")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
      expect(view_source).to include(%(data-rails-table-preferences-column-key="#{column_key}"))
    end

    expect(helper_source).to include("table_preferences_column(:project, label: \"案件\", default_width: 220, pinned: true")
    expect(helper_source).to include("table_preferences_column(:actions, label: \"操作\", default_width: 230, pinned: true)")
    expect(view_source).to include("data-graph-connection-field=\"drive\"")
    expect(view_source).to include("data-graph-connection-field=\"preview-folder\"")
    expect(view_source).to include("admin_external_folder_sync_sources_path(review: :microsoft_graph")
  end
end
