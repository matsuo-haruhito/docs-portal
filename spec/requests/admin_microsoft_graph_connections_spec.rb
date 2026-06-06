require "rails_helper"

RSpec.describe "Admin Microsoft Graph connections", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }
  let(:shared_folder_url) { "https://contoso.sharepoint.com/:f:/s/DocsPortal/ExampleSharedFolder" }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def input_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def safe_identifier_preview(value)
    normalized = value.to_s.squish
    return normalized if normalized.length <= 28

    "#{normalized.first(10)}...#{normalized.last(8)}"
  end

  describe "GET /admin/microsoft_graph_connections" do
    it "shows which enabled connection is currently used for preview" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      create(:microsoft_graph_connection, project:, name: "Standby connection", enabled: false)
      create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).to include("previewで使用中")
      expect(response.body).to include("previewでは未使用")
    end

    it "highlights legacy duplicate enabled connections that need cleanup" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("同一案件に複数の有効接続が残っています")
      expect(response.body).to include("有効だが未使用")
      expect(response.body).to include("別の有効接続が preview に使われます")
    end

    it "renders quick filters and duplicate cleanup links for daily review" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)
      create(:microsoft_graph_connection, project:, name: "Disabled connection", enabled: false)
      create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("一覧の絞り込み")
      expect(response.body).to include("previewで使用中 (2)")
      expect(response.body).to include("有効だが未使用 (1)")
      expect(response.body).to include("無効 / previewでは未使用 (1)")
      expect(response.body).to include("要整理案件のみ (1案件)")

      duplicate_project_link = parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(duplicate_only: 1)}#microsoft-graph-project-#{project.id}"]))

      expect(duplicate_project_link).to be_present
      expect(duplicate_project_link.text).to include(project.name)
    end

    it "filters the table to preview-selected connections" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)
      disabled = create(:microsoft_graph_connection, project:, name: "Disabled connection", enabled: false)
      other_active = create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path, params: { preview_usage: "preview_selected" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).to include(other_active.name)
      expect(response.body).not_to include(duplicate.name)
      expect(response.body).not_to include(disabled.name)
      expect(response.body).to include("現在の絞り込み: previewで使用中")
      expect(response.body).to include("2 / 4 件を表示しています。")
    end

    it "filters the table to enabled but unused connections" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)
      disabled = create(:microsoft_graph_connection, project:, name: "Disabled connection", enabled: false)
      other_active = create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path, params: { preview_usage: "enabled_unused" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(duplicate.name)
      expect(response.body).not_to include(active.name)
      expect(response.body).not_to include(disabled.name)
      expect(response.body).not_to include(other_active.name)
      expect(response.body).to include("現在の絞り込み")
      expect(response.body).to include("1 / 4 件を表示しています。")
    end

    it "filters the table to disabled connections" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      disabled = create(:microsoft_graph_connection, project:, name: "Disabled connection", enabled: false)
      other_disabled = create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other disabled", enabled: false)

      get admin_microsoft_graph_connections_path, params: { preview_usage: "disabled" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(disabled.name)
      expect(response.body).to include(other_disabled.name)
      expect(response.body).not_to include(active.name)
      expect(response.body).to include("現在の絞り込み: 無効 / previewでは未使用")
      expect(response.body).to include("2 / 3 件を表示しています。")
    end

    it "filters the table to duplicate projects only" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)
      other_active = create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path, params: { duplicate_only: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).to include(duplicate.name)
      expect(response.body).not_to include(other_active.name)
      expect(response.body).to include("microsoft-graph-project-#{project.id}")
      expect(response.body).to include("2 / 3 件を表示しています。")
    end

    it "searches connections by project and Graph connection fields" do
      sign_in_as(admin_user)
      target_project = create(:project, code: "APOLLO42", name: "Apollo Launch")
      target = create(
        :microsoft_graph_connection,
        project: target_project,
        name: "Launch preview",
        tenant_id: "tenant-alpha",
        client_id: "client-alpha",
        site_id: "site-alpha",
        drive_id: "drive-alpha",
        preview_folder_path: "Shared Documents/Apollo"
      )
      other = create(:microsoft_graph_connection, project: create(:project, code: "BETA01", name: "Beta Project"), name: "Beta preview", drive_id: "drive-beta")

      get admin_microsoft_graph_connections_path, params: { q: "apollo" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.name)
      expect(response.body).to include(target_project.code)
      expect(response.body).not_to include(other.name)
      expect(response.body).to include("検索: apollo")
      expect(response.body).to include("1 / 2 件を表示しています。")
      expect(input_value("q")).to eq("apollo")
    end

    it "searches connections by site and preview folder metadata" do
      sign_in_as(admin_user)
      target = create(
        :microsoft_graph_connection,
        project:,
        name: "Metadata preview",
        site_id: "contoso.sharepoint.com,site-alpha,web-alpha",
        preview_folder_path: "Shared Documents/Launch Reviews"
      )
      other = create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other preview", site_id: "contoso.sharepoint.com,site-beta,web-beta")

      get admin_microsoft_graph_connections_path, params: { q: "site-alpha" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(target.name)
      expect(response.body).not_to include(other.name)
      expect(response.body).to include("検索: site-alpha")
      expect(response.body).to include("1 / 2 件を表示しています。")
    end

    it "groups long Graph identifiers into prioritized readable cells" do
      sign_in_as(admin_user)
      long_tenant_id = "tenant-#{'northwind-' * 8}primary"
      long_client_id = "client-#{'application-' * 8}id"
      long_drive_id = "b!#{'driveIdentifierSegment' * 5}"
      long_site_id = "contoso.sharepoint.com,#{'site-id-' * 6}web-id"
      long_folder_path = "Shared Documents/#{'Department Folder/' * 5}Office Preview"
      connection = create(
        :microsoft_graph_connection,
        project:,
        name: "Long identifiers",
        tenant_id: long_tenant_id,
        client_id: long_client_id,
        site_id: long_site_id,
        drive_id: long_drive_id,
        preview_folder_path: long_folder_path,
        enabled: true
      )

      get admin_microsoft_graph_connections_path

      row = parsed_html.css("tbody tr").find { |node| node.text.include?(connection.name) }

      expect(response).to have_http_status(:ok)
      expect(row).to be_present
      expect(row.at_css(%([data-graph-connection-field="drive"] code.graph-connection-value)).text).to eq(safe_identifier_preview(long_drive_id))
      expect(row.at_css(%([data-graph-connection-field="preview-folder"] code.graph-connection-value)).text).to eq(safe_identifier_preview(long_folder_path))
      expect(row.at_css(%([data-graph-connection-field="tenant"] code.graph-connection-value)).text).to eq(safe_identifier_preview(long_tenant_id))
      expect(row.at_css(%([data-graph-connection-field="client"] code.graph-connection-value)).text).to eq(safe_identifier_preview(long_client_id))
      expect(row.at_css(%([data-graph-connection-field="site"] code.graph-connection-value)).text).to eq(safe_identifier_preview(long_site_id))
      expect(response.body).not_to include(long_drive_id)
      expect(response.body).not_to include(long_folder_path)
      expect(response.body).not_to include(long_tenant_id)
      expect(response.body).not_to include(long_client_id)
      expect(response.body).not_to include(long_site_id)
      expect(row.text.squish).to include("主確認: Drive ID")
      expect(row.text.squish).to include("主確認: プレビュー用フォルダ")
      expect(row.text.squish).to include("補助: Tenant ID")
      expect(row.text.squish).to include("補助: Client ID")
      expect(row.text.squish).to include("補助: Site ID")
      expect(row.at_css(%(a[href="#{edit_admin_microsoft_graph_connection_path(connection)}"])).text).to include("編集")
    end

    it "keeps the search query while applying preview usage filters" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Archive primary", enabled: true)
      disabled = create(:microsoft_graph_connection, project:, name: "Archive disabled", enabled: false)
      create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other disabled", enabled: false)

      get admin_microsoft_graph_connections_path, params: { q: "Archive", preview_usage: "disabled" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(disabled.name)
      expect(response.body).not_to include(active.name)
      expect(response.body).to include("現在の絞り込み: 無効 / previewでは未使用 / 検索: Archive")
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(preview_usage: :enabled_unused, q: "Archive")}"]))).to be_present
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(preview_usage: "disabled")}"])).text).to include("検索を解除")
    end

    it "combines duplicate cleanup filtering with the search query" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Standby cleanup", enabled: false, drive_id: "standby-drive")
      duplicate.update_column(:enabled, true)
      other_duplicate_project = create(:project, code: "GRAPH002", name: "Other Project")
      create(:microsoft_graph_connection, project: other_duplicate_project, name: "Other primary", enabled: true)
      other_duplicate = create(:microsoft_graph_connection, project: other_duplicate_project, name: "Other duplicate", enabled: false)
      other_duplicate.update_column(:enabled, true)

      get admin_microsoft_graph_connections_path, params: { duplicate_only: "1", q: "standby" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(duplicate.name)
      expect(response.body).not_to include("Primary connection")
      expect(response.body).not_to include(other_duplicate.name)
      expect(response.body).to include("現在の絞り込み: 要整理案件のみ / 検索: standby")
      expect(response.body).to include("1 / 4 件を表示しています。")
    end

    it "shows filtered empty state separately from an unregistered empty state" do
      sign_in_as(admin_user)
      connection = create(:microsoft_graph_connection, project:, name: "Primary connection")

      get admin_microsoft_graph_connections_path, params: { q: "missing" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(connection.name)
      expect(response.body).to include("現在の絞り込みに一致する Microsoft Graph接続はありません。")
      expect(response.body).to include("検索と絞り込みを解除")
      expect(response.body).not_to include("まだMicrosoft Graph接続は登録されていません。")
    end

    it "treats a blank search query as no search" do
      sign_in_as(admin_user)
      connection = create(:microsoft_graph_connection, project:, name: "Primary connection")

      get admin_microsoft_graph_connections_path, params: { q: "   " }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(connection.name)
      expect(response.body).not_to include("検索:")
      expect(response.body).to include("1 / 1 件を表示しています。")
    end

    it "ignores unsupported filter values without keeping active filter labels" do
      sign_in_as(admin_user)
      connection = create(:microsoft_graph_connection, project:, name: "Primary connection")

      get admin_microsoft_graph_connections_path, params: { preview_usage: "archived", duplicate_only: "true", q: "   " }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(connection.name)
      expect(response.body).to include("1 / 1 件を表示しています。")
      expect(response.body).not_to include("現在の絞り込み")
      expect(response.body).not_to include("archived")
    end

    it "shows an unregistered empty state when no connections exist" do
      sign_in_as(admin_user)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("まだMicrosoft Graph接続は登録されていません。")
      expect(response.body).to include("上の「新規登録」で案件、接続名、Tenant ID、Client ID、Drive ID、プレビュー用フォルダを設定して最初の接続を保存してください。")
      expect(response.body).not_to include("現在の絞り込みに一致する Microsoft Graph接続はありません。")
      expect(response.body).not_to include("一覧の絞り込み")
    end
  end

  describe "POST /admin/microsoft_graph_connections" do
    it "rejects creating a second enabled connection for the same project" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, enabled: true)

      expect do
        post admin_microsoft_graph_connections_path, params: {
          microsoft_graph_connection: {
            project_id: project.id,
            name: "Replacement connection",
            auth_type: "client_credentials",
            tenant_id: "tenant-id",
            client_id: "client-id",
            client_secret: "client-secret",
            site_id: "site-id",
            drive_id: "drive-id-2",
            preview_folder_path: "docs-portal-previews-2",
            enabled: "true"
          }
        }
      end.not_to change(MicrosoftGraphConnection, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("同一案件で1件だけ有効にできます")
      expect(response.body).to include("現在の有効接続を先に無効化")
    end

    it "fills drive details from a shared folder url without saving" do
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
        post admin_microsoft_graph_connections_path, params: {
          resolve_share_url: "1",
          microsoft_graph_connection: {
            project_id: project.id,
            name: "Office preview",
            auth_type: "client_credentials",
            tenant_id: "tenant-id",
            client_id: "client-id",
            client_secret: "client-secret",
            site_id: "",
            drive_id: "",
            preview_folder_path: "",
            shared_folder_url: shared_folder_url,
            enabled: "true"
          }
        }
      end.not_to change(MicrosoftGraphConnection, :count)

      expect(response).to have_http_status(:ok)
      expect(input_value("microsoft_graph_connection[drive_id]")).to eq("b!resolved-drive")
      expect(input_value("microsoft_graph_connection[site_id]")).to eq("contoso.sharepoint.com,site-id,web-id")
      expect(input_value("microsoft_graph_connection[preview_folder_path]")).to eq("Shared Documents/Docs Portal Previews")
      expect(MicrosoftGraphSharedFolderResolver).to have_received(:new).with(
        tenant_id: "tenant-id",
        client_id: "client-id",
        client_secret: "client-secret",
        shared_folder_url: shared_folder_url
      )
    end

    it "shows a resolve error without attempting to save" do
      sign_in_as(admin_user)
      resolver = instance_double(MicrosoftGraphSharedFolderResolver)
      allow(MicrosoftGraphSharedFolderResolver).to receive(:new).and_return(resolver)
      allow(resolver).to receive(:resolve).and_raise(
        MicrosoftGraphSharedFolderResolver::ResolutionError,
        "共有URLからDrive情報を解決できませんでした。"
      )

      expect do
        post admin_microsoft_graph_connections_path, params: {
          resolve_share_url: "1",
          microsoft_graph_connection: {
            project_id: project.id,
            name: "Office preview",
            auth_type: "client_credentials",
            tenant_id: "tenant-id",
            client_id: "client-id",
            client_secret: "client-secret",
            site_id: "",
            drive_id: "",
            preview_folder_path: "",
            shared_folder_url: shared_folder_url,
            enabled: "true"
          }
        }
      end.not_to change(MicrosoftGraphConnection, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("共有URLからDrive情報を解決できませんでした。")
      expect(input_value("microsoft_graph_connection[shared_folder_url]")).to eq(shared_folder_url)
    end
  end

  describe "PATCH /admin/microsoft_graph_connections/:public_id" do
    it "uses the stored client secret when resolving from edit" do
      sign_in_as(admin_user)
      connection = create(
        :microsoft_graph_connection,
        project:,
        name: "Existing connection",
        tenant_id: "tenant-id",
        client_id: "client-id",
        client_secret: "stored-secret",
        site_id: "old-site-id",
        drive_id: "old-drive-id",
        preview_folder_path: "old-folder",
        enabled: true
      )

      resolved_result = instance_double(
        MicrosoftGraphSharedFolderResolver::Result,
        drive_id: "b!updated-drive",
        site_id: "contoso.sharepoint.com,new-site-id,new-web-id",
        preview_folder_path: "Shared Documents/New Preview Folder"
      )
      resolver = instance_double(MicrosoftGraphSharedFolderResolver, resolve: resolved_result)
      allow(MicrosoftGraphSharedFolderResolver).to receive(:new).and_return(resolver)

      expect do
        patch admin_microsoft_graph_connection_path(connection), params: {
          resolve_share_url: "1",
          microsoft_graph_connection: {
            project_id: connection.project_id,
            name: connection.name,
            auth_type: connection.auth_type,
            tenant_id: connection.tenant_id,
            client_id: connection.client_id,
            client_secret: "",
            site_id: connection.site_id,
            drive_id: connection.drive_id,
            preview_folder_path: connection.preview_folder_path,
            shared_folder_url: shared_folder_url,
            enabled: connection.enabled?.to_s
          }
        }
      end.not_to change { connection.reload.drive_id }

      expect(response).to have_http_status(:ok)
      expect(input_value("microsoft_graph_connection[drive_id]")).to eq("b!updated-drive")
      expect(input_value("microsoft_graph_connection[site_id]")).to eq("contoso.sharepoint.com,new-site-id,new-web-id")
      expect(input_value("microsoft_graph_connection[preview_folder_path]")).to eq("Shared Documents/New Preview Folder")
      expect(MicrosoftGraphSharedFolderResolver).to have_received(:new).with(
        tenant_id: "tenant-id",
        client_id: "client-id",
        client_secret: "stored-secret",
        shared_folder_url: shared_folder_url
      )
    end
  end
end
