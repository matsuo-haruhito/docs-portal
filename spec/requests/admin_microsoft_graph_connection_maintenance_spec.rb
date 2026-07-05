require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH-MAINT", name: "Graph Maintenance") }
  let(:shared_folder_url) { "https://contoso.sharepoint.com/:f:/s/DocsPortal/ExampleSharedFolder" }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(Admin::MicrosoftGraphConnectionsController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[Admin::MicrosoftGraphConnectionsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(Admin::MicrosoftGraphConnectionsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::MicrosoftGraphConnectionsController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def input_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def graph_connection_params(overrides = {})
    {
      project_id: project.id,
      name: "Maintenance Graph",
      auth_type: "client_credentials",
      tenant_id: "tenant-maintenance",
      client_id: "client-maintenance",
      client_secret: "client-secret",
      site_id: "site-maintenance",
      drive_id: "drive-maintenance",
      preview_folder_path: "docs-portal-previews",
      shared_folder_url: shared_folder_url,
      enabled: "true"
    }.merge(overrides)
  end

  it "does not create Microsoft Graph connections during read-only maintenance" do
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        post admin_microsoft_graph_connections_path, params: {
          microsoft_graph_connection: graph_connection_params
        }
      end
    end.not_to change(MicrosoftGraphConnection, :count)

    expect(response).to redirect_to(admin_microsoft_graph_connections_path)
    expect(flash[:alert]).to include("メンテナンス中のためMicrosoft Graph接続設定の作成・更新・削除は停止しています")
  end

  it "does not update Microsoft Graph connection settings during read-only maintenance" do
    connection = create(
      :microsoft_graph_connection,
      project: project,
      name: "Original Graph",
      tenant_id: "tenant-original",
      client_id: "client-original",
      client_secret: "stored-secret",
      site_id: "site-original",
      drive_id: "drive-original",
      preview_folder_path: "original-preview",
      enabled: true
    )
    sign_in_as(admin_user)

    with_read_only_maintenance("true") do
      patch admin_microsoft_graph_connection_path(connection), params: {
        microsoft_graph_connection: graph_connection_params(
          name: "Changed Graph",
          tenant_id: "tenant-changed",
          client_id: "client-changed",
          client_secret: "changed-secret",
          site_id: "site-changed",
          drive_id: "drive-changed",
          preview_folder_path: "changed-preview",
          enabled: "false"
        )
      }
    end

    expect(response).to redirect_to(edit_admin_microsoft_graph_connection_path(connection.public_id))
    expect(flash[:alert]).to include("メンテナンス中のためMicrosoft Graph接続設定の作成・更新・削除は停止しています")
    connection.reload
    expect(connection).to have_attributes(
      name: "Original Graph",
      tenant_id: "tenant-original",
      client_id: "client-original",
      client_secret: "stored-secret",
      site_id: "site-original",
      drive_id: "drive-original",
      preview_folder_path: "original-preview",
      enabled: true
    )
  end

  it "does not destroy Microsoft Graph connections during read-only maintenance" do
    connection = create(:microsoft_graph_connection, project: project, name: "Persistent Graph")
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        delete admin_microsoft_graph_connection_path(connection)
      end
    end.not_to change(MicrosoftGraphConnection, :count)

    expect(response).to redirect_to(admin_microsoft_graph_connections_path)
    expect(flash[:alert]).to include("メンテナンス中のためMicrosoft Graph接続設定の作成・更新・削除は停止しています")
    expect(connection.reload).to be_persisted
  end

  it "keeps Microsoft Graph lists and project lookup readable during read-only maintenance" do
    connection = create(:microsoft_graph_connection, project: project, name: "Readable Graph", enabled: true)
    sign_in_as(admin_user)

    with_read_only_maintenance("1") do
      get admin_microsoft_graph_connections_path, params: { q: "Readable" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(connection.name)
      expect(response.body).to include("previewで使用中")

      get project_search_admin_microsoft_graph_connections_path, params: { q: project.code.first(8) }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("options").first).to include("value" => project.id)

      get selected_project_admin_microsoft_graph_connections_path, params: { id: project.id }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("option")).to include("value" => project.id)
    end
  end

  it "keeps shared URL candidate resolution available without saving during read-only maintenance" do
    sign_in_as(admin_user)
    resolved_result = instance_double(
      MicrosoftGraphSharedFolderResolver::Result,
      drive_id: "b!resolved-drive",
      site_id: "contoso.sharepoint.com,site-id,web-id",
      preview_folder_path: "Shared Documents/Docs Portal Previews"
    )
    resolver = instance_double(MicrosoftGraphSharedFolderResolver, resolve: resolved_result)
    allow(MicrosoftGraphSharedFolderResolver).to receive(:new).and_return(resolver)

    expect do
      with_read_only_maintenance("1") do
        post admin_microsoft_graph_connections_path, params: {
          resolve_share_url: "1",
          microsoft_graph_connection: graph_connection_params(site_id: "", drive_id: "", preview_folder_path: "")
        }
      end
    end.not_to change(MicrosoftGraphConnection, :count)

    expect(response).to have_http_status(:ok)
    expect(input_value("microsoft_graph_connection[drive_id]")).to eq("b!resolved-drive")
    expect(input_value("microsoft_graph_connection[site_id]")).to eq("contoso.sharepoint.com,site-id,web-id")
    expect(input_value("microsoft_graph_connection[preview_folder_path]")).to eq("Shared Documents/Docs Portal Previews")
    expect(MicrosoftGraphSharedFolderResolver).to have_received(:new).with(
      tenant_id: "tenant-maintenance",
      client_id: "client-maintenance",
      client_secret: "client-secret",
      shared_folder_url: shared_folder_url
    )
  end

  it "keeps Microsoft Graph connection CRUD working when read-only maintenance is disabled" do
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("0") do
        post admin_microsoft_graph_connections_path, params: {
          microsoft_graph_connection: graph_connection_params(name: "Writable Graph")
        }
      end
    end.to change(MicrosoftGraphConnection, :count).by(1)

    connection = MicrosoftGraphConnection.order(:id).last
    expect(response).to redirect_to(admin_microsoft_graph_connections_path)
    expect(connection.name).to eq("Writable Graph")

    with_read_only_maintenance("0") do
      patch admin_microsoft_graph_connection_path(connection), params: {
        microsoft_graph_connection: graph_connection_params(
          name: "Writable Graph Updated",
          client_secret: "",
          enabled: "false"
        )
      }
    end

    expect(response).to redirect_to(admin_microsoft_graph_connections_path)
    connection.reload
    expect(connection.name).to eq("Writable Graph Updated")
    expect(connection.enabled).to eq(false)

    expect do
      with_read_only_maintenance("0") do
        delete admin_microsoft_graph_connection_path(connection)
      end
    end.to change(MicrosoftGraphConnection, :count).by(-1)
    expect(response).to redirect_to(admin_microsoft_graph_connections_path)
  end
end
