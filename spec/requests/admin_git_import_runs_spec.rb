require "rails_helper"

RSpec.describe "Admin git import runs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "GIT", name: "Git Import Project") }
  let(:git_import_source) { create(:git_import_source, project:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def run_rows
    parsed_html.css("table tbody tr")
  end

  def create_git_import_run!(git_import_source: self.git_import_source, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"), status: :imported, summary_json: { imported: 1 }, error_message: nil)
    GitImportRun.create!(
      git_import_source:,
      repository_full_name: git_import_source.repository_full_name,
      branch: git_import_source.branch,
      source_path: git_import_source.source_path,
      provider: :github,
      import_mode: :pull,
      status:,
      commit_sha: "abcdef1234567890",
      summary_json:,
      error_message:,
      created_at:,
      updated_at: created_at
    )
  end

  it "shows an empty state when no runs exist yet" do
    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだGit同期履歴はありません。")
    expect(page_text).to include("Git連携 で案件、リポジトリ、ブランチ、取込元パスを設定し、「手動同期」を実行すると、ここに履歴が表示されます。")
    expect(page_text).to include("この画面では、同期結果やエラー内容をあとから確認できます。")
    expect(response.body).not_to include("Git同期履歴の表示設定")
    expect(response.body).not_to include('data-rails-table-preferences-column-key="created_at"')
  end

  it "shows git import history when runs exist" do
    create_git_import_run!

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Git同期履歴")
    expect(response.body).to include("Git Import Project")
    expect(response.body).to include(git_import_source.repository_full_name)
    expect(page_text).to include("表示中: 1件 / 最新100件までを表示")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(run_rows.size).to eq(1)
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:forbidden)
  end
end
