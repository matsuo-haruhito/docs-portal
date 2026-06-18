require "rails_helper"

RSpec.describe "Admin git import run diagnostic cues", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GIT", name: "Git Import Project") }
  let(:git_import_source) { create(:git_import_source, project:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_git_import_run!(status: :imported, summary_json: { "documents" => 2, "source_path" => "docs" }, error_message: nil, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"))
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

  it "labels summary_json detail and error_message preview separately in each row" do
    create_git_import_run!(
      status: :failed,
      summary_json: { "documents" => 2, "source_path" => "docs", "credentials" => { "access_token" => "secret-token" } },
      error_message: "fatal token=secret-token failed at /home/alice/docs"
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("summary_json の要約")
    expect(page_text).to include("summary_json のマスク済み詳細")
    expect(page_text).to include("error_message のマスク済み preview")
    expect(page_text).to include("取り込み文書: 2")
    expect(response.body).to include("[masked]")
    expect(response.body).to include("[path hidden]")
    expect(response.body).not_to include("secret-token")
    expect(response.body).not_to include("/home/alice/docs")
  end

  it "uses column-specific empty copy without changing table preference keys" do
    create_git_import_run!(summary_json: { "provider_error" => "masked context only" }, error_message: nil)

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("summary_json の要約なし")
    expect(page_text).to include("エラーなし")
    expect(response.body).to include('data-rails-table-preferences-column-key="summary"')
    expect(response.body).to include('data-rails-table-preferences-column-key="error_message"')
  end
end
