require "rails_helper"

RSpec.describe "Admin git import source form cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "shows the recommended auth path and keeps advanced settings visually scoped" do
    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("通常運用は GitHub App。Fine-grained PAT は開発・検証用、認証なしは公開リポジトリ限定です。")
    expect(response.body).to include("詳細設定（通常は開かない管理者・検証向け）")
    expect(response.body).to include("installation ID や credential ref / secret は、GitHub App 導入前の検証や管理者の調整が必要な場合だけ確認します。")
    expect(response.body).to include("Fine-grained PAT を使う場合のみ入力します。GitHub App や公開リポジトリでは空欄のまま保存できます。")
  end

  it "explains persisted credential updates without exposing the saved secret" do
    project = create(:project, code: "GITCUE", name: "Git Cue Project")
    source = create(
      :git_import_source,
      project:,
      created_by: admin_user,
      repository_full_name: "example/git-cue-docs",
      auth_type: :fine_grained_pat,
      credential_secret: "existing-token"
    )

    get edit_admin_git_import_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存済みシークレットは表示しません。空欄のまま保存すると既存値を維持し、新しい値を入力したときだけ更新します。")
    expect(response.body).to include("変更時のみ入力")
    expect(response.body).not_to include("existing-token")
  end
end
