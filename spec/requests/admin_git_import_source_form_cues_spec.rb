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
    expect(response.body).to include("詳細設定は、GitHub App の installation ID や PAT の参照名・secret を確認するときだけ開きます。")
    expect(response.body).to include("詳細設定（通常は開かない管理者・検証向け）")
    expect(response.body).to include("GitHub App では installation ID を確認します。Fine-grained PAT では credential ref と secret を使い、no_auth では secret は不要です。")
    expect(response.body).to include("Fine-grained PAT を使う場合のみ入力します。GitHub App や公開リポジトリの認証なしでは空欄のまま保存できます。")
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
    expect(response.body).to include("保存済みシークレットは表示しません。Fine-grained PAT の値を変更するときだけ入力します。")
    expect(response.body).to include("GitHub App や認証なしの設定では空欄のまま保存できます。")
    expect(response.body).to include("変更時のみ入力")
    expect(response.body).not_to include("existing-token")
  end
end
