require "rails_helper"

RSpec.describe "Admin git import source sync confirm", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GIT", name: "Git Import Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "includes project, repository, branch, source path, and state in the manual sync confirmation" do
    source = create(
      :git_import_source,
      project:,
      repository_full_name: "matsuo-haruhito/docs-portal",
      branch: "release/docs",
      source_path: "handbook"
    )

    sign_in_as(admin_user)

    get admin_git_import_sources_path

    sync_form = parsed_html.at_css(%(form[action="#{sync_admin_git_import_source_path(source)}"][data-turbo-confirm]))

    expect(response).to have_http_status(:ok)
    expect(sync_form).to be_present

    confirm_copy = sync_form["data-turbo-confirm"]
    expect(confirm_copy).to include("Git連携設定を手動同期します。")
    expect(confirm_copy).to include("案件: GIT / Git Import Project")
    expect(confirm_copy).to include("リポジトリ: matsuo-haruhito/docs-portal")
    expect(confirm_copy).to include("ブランチ: release/docs")
    expect(confirm_copy).to include("取込元パス: handbook")
    expect(confirm_copy).to include("状態: 有効")
  end
end
