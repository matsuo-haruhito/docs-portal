require "rails_helper"

RSpec.describe "Admin git import source branch options", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  def json_body
    JSON.parse(response.body)
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "returns GitHub App branch options through the repository search endpoint" do
    result = GitHubAppBranchOptions::Result.new(
      branches: ["main", "release/docs"],
      fallback: false,
      message: nil
    )
    service = instance_double(GitHubAppBranchOptions, call: result)
    expect(GitHubAppBranchOptions).to receive(:new).with(
      installation_id: "12345",
      repository_full_name: "example/docs-portal",
      query: "rel",
      limit: Admin::GitImportSourcesController::BRANCH_SEARCH_LIMIT
    ).and_return(service)

    get repository_search_admin_git_import_sources_path(format: :json), params: {
      kind: "branch",
      installation_id: "12345",
      repository_full_name: "example/docs-portal",
      q: "rel"
    }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([
      { "value" => "main", "text" => "main" },
      { "value" => "release/docs", "text" => "release/docs" }
    ])
    expect(json_body.fetch("fallback")).to be(false)
    expect(json_body.fetch("message")).to be_nil
  end

  it "falls back to manual branch input when GitHub App branch options are unavailable" do
    result = GitHubAppBranchOptions::Result.new(
      branches: [],
      fallback: true,
      message: "リポジトリが未選択のため、ブランチは手入力してください。"
    )
    allow(GitHubAppBranchOptions).to receive(:new).and_return(instance_double(GitHubAppBranchOptions, call: result))

    get repository_search_admin_git_import_sources_path(format: :json), params: { kind: "branch", q: "main" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([])
    expect(json_body.fetch("fallback")).to be(true)
    expect(json_body.fetch("message")).to include("手入力してください")
  end

  it "keeps saved branches visible even when candidates are unavailable or outside the search result window" do
    project = create(:project, code: "BRANCH", name: "Branch Project")
    source = create(
      :git_import_source,
      project:,
      created_by: admin_user,
      repository_full_name: "example/selected-docs",
      branch: "release/outside-window",
      installation_id: "12345"
    )

    get edit_admin_git_import_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("release/outside-window")
    expect(page_text).to include("リポジトリとブランチは GitHub App の候補から選べます。")
    expect(page_text).to include("候補取得不可・候補0件の場合は、既存どおり owner/repo とブランチ名を直接入力します。")
  end
end
