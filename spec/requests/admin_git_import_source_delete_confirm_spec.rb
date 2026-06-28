require "rails_helper"

RSpec.describe "Admin git import source delete confirmation", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "identifies the target project and repository before deleting a source" do
    active_project = create(:project, code: "GIT001", name: "Main Docs")
    disabled_project = create(:project, code: "GIT002", name: "Archive Docs")
    create(
      :git_import_source,
      project: active_project,
      repository_full_name: "example/shared-docs",
      branch: "release/main",
      source_path: "docs/current",
      enabled: true
    )
    disabled_source = create(
      :git_import_source,
      project: disabled_project,
      repository_full_name: "example/shared-docs",
      branch: "release/archive",
      source_path: "docs/archive",
      enabled: false
    )
    disabled_source.update_column(:source_path, "")

    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Git連携設定を削除します。案件: GIT001 / Main Docs、リポジトリ: example/shared-docs、ブランチ: release/main、取込元パス: docs/current、状態: 有効"
    )
    expect(response.body).to include(
      "Git連携設定を削除します。案件: GIT002 / Archive Docs、リポジトリ: example/shared-docs、ブランチ: release/archive、取込元パス: /、状態: 無効"
    )
    expect(response.body).not_to include("Git連携設定を削除しますか？")
  end
end
