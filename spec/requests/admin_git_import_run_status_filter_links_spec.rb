require "rails_helper"

RSpec.describe "Admin git import run status filter links", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GIT", name: "Git Import Project") }
  let(:git_import_source) do
    create(
      :git_import_source,
      project:,
      repository_full_name: "matsuo-haruhito/docs-portal",
      branch: "release/2026",
      source_path: "docs/product"
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_git_import_run!(status:, created_at:, summary_json: {}, error_message: nil, commit_sha: "abc123def4567890")
    GitImportRun.create!(
      git_import_source:,
      repository_full_name: git_import_source.repository_full_name,
      branch: git_import_source.branch,
      source_path: git_import_source.source_path,
      provider: :github,
      import_mode: :pull,
      status:,
      commit_sha:,
      summary_json:,
      error_message:,
      created_at:,
      updated_at: created_at
    )
  end

  def query_params_for_link(label)
    href = parsed_html.at_xpath("//a[normalize-space(.)='#{label}']")["href"]

    Rack::Utils.parse_nested_query(href.split("?", 2).last)
  end

  it "links failed and skipped summary counts to status filters while preserving current filters" do
    create_git_import_run!(status: :failed, error_message: "repository not found", created_at: Time.zone.parse("2026-05-03 00:00:00 UTC"))
    create_git_import_run!(status: :skipped, summary_json: { "reason" => "already_synced" }, created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))
    create_git_import_run!(status: :imported, summary_json: { "reason" => "imported" }, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"))

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: {
      project_id: project.id,
      repository: "docs-portal",
      branch: "RELEASE",
      source_path: "product",
      commit: "abc123"
    }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("状態サマリから、現在の案件・リポジトリ・ブランチ・パス・コミット条件を保ったまま絞り込めます。")

    expect(query_params_for_link("失敗 1件に絞り込む")).to include(
      "status" => "failed",
      "project_id" => project.id.to_s,
      "repository" => "docs-portal",
      "branch" => "RELEASE",
      "source_path" => "product",
      "commit" => "abc123"
    )
    expect(query_params_for_link("スキップ 1件に絞り込む")).to include(
      "status" => "skipped",
      "project_id" => project.id.to_s,
      "repository" => "docs-portal",
      "branch" => "RELEASE",
      "source_path" => "product",
      "commit" => "abc123"
    )
  end

  it "does not render a self-link for the currently applied status filter" do
    create_git_import_run!(status: :failed, error_message: "repository not found", created_at: Time.zone.parse("2026-05-03 00:00:00 UTC"))

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "failed", repository: "docs-portal" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_xpath("//a[normalize-space(.)='失敗 1件に絞り込む']")).to be_nil

    current_status_item = parsed_html.at_xpath("//li[normalize-space(.)='失敗 1件を表示中']")
    expect(current_status_item).to be_present
    expect(current_status_item.at_css("a")).to be_nil
  end
end
