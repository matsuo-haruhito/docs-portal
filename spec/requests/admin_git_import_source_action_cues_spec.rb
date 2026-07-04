require "rails_helper"

RSpec.describe "Admin git import source action cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def row_for(repository_full_name)
    parsed_html.css("tbody tr").find { |row| row.text.include?(repository_full_name) }
  end

  before do
    sign_in_as(admin_user)
  end

  it "shows one list-level action cue while keeping row actions and confirmations specific" do
    active_project = create(:project, code: "GIT001", name: "Main Docs")
    disabled_project = create(:project, code: "GIT002", name: "Archive Docs")
    active_source = create(
      :git_import_source,
      project: active_project,
      repository_full_name: "example/active-docs",
      branch: "release/main",
      source_path: "docs/current",
      enabled: true
    )
    disabled_source = create(
      :git_import_source,
      project: disabled_project,
      repository_full_name: "example/disabled-docs",
      branch: "release/archive",
      source_path: "docs/archive",
      enabled: false
    )

    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Git連携設定一覧の操作は、手動同期=今すぐ取り込み、編集=設定変更、削除=設定削除です。")
    expect(page_text.scan("手動同期=今すぐ取り込み").size).to eq(1)

    active_row = row_for("example/active-docs")
    disabled_row = row_for("example/disabled-docs")
    expect(active_row.text.squish).to include("有効")
    expect(disabled_row.text.squish).to include("無効")
    expect(active_row.text.squish).not_to include("手動同期=今すぐ取り込み")
    expect(disabled_row.text.squish).not_to include("手動同期=今すぐ取り込み")
    expect(active_row.css(%(form[action="#{sync_admin_git_import_source_path(active_source)}"] button)).text.squish).to eq("手動同期")
    expect(disabled_row.css(%(form[action="#{sync_admin_git_import_source_path(disabled_source)}"] button)).text.squish).to eq("手動同期")
    expect(active_row.css(%(a[href="#{edit_admin_git_import_source_path(active_source)}"])).text.squish).to include("編集")
    expect(disabled_row.css(%(a[href="#{edit_admin_git_import_source_path(disabled_source)}"])).text.squish).to include("編集")

    expect(response.body).to include(
      "Git連携設定を手動同期します。案件: GIT001 / Main Docs、リポジトリ: example/active-docs、ブランチ: release/main、取込元パス: docs/current、状態: 有効。今すぐ取り込みを実行し、設定の編集や削除は行いません。"
    )
    expect(response.body).to include(
      "Git連携設定を手動同期します。案件: GIT002 / Archive Docs、リポジトリ: example/disabled-docs、ブランチ: release/archive、取込元パス: docs/archive、状態: 無効。今すぐ取り込みを実行し、設定の編集や削除は行いません。"
    )
    expect(response.body).to include(
      "Git連携設定を削除します。案件: GIT001 / Main Docs、リポジトリ: example/active-docs、ブランチ: release/main、取込元パス: docs/current、状態: 有効。手動同期ではなく、設定を削除する操作です。"
    )
    expect(response.body).to include(
      "Git連携設定を削除します。案件: GIT002 / Archive Docs、リポジトリ: example/disabled-docs、ブランチ: release/archive、取込元パス: docs/archive、状態: 無効。手動同期ではなく、設定を削除する操作です。"
    )
  end
end
