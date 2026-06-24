require "rails_helper"

RSpec.describe "Admin git import operational metadata exposure", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_git_import_run!(git_import_source:, status: :imported, summary_json: {}, error_message: nil)
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
      created_at: Time.zone.local(2026, 6, 24, 10, 0, 0),
      updated_at: Time.zone.local(2026, 6, 24, 10, 0, 0)
    )
  end

  it "keeps source credentials hidden while showing operational identifiers" do
    sign_in_as(admin_user)
    project = create(:project, code: "GIT3830", name: "Git Metadata Project")
    source = create(
      :git_import_source,
      project:,
      created_by: admin_user,
      repository_full_name: "matsuo-haruhito/private-docs",
      branch: "release/main",
      source_path: "docs/operations",
      auth_type: :fine_grained_pat,
      installation_id: "987654321",
      credential_ref: "vault/git/source-token-3830",
      credential_secret: "raw-source-secret-3830",
      last_synced_commit_sha: "abcdef1234567890",
      last_synced_at: Time.zone.local(2026, 6, 24, 9, 0, 0)
    )

    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Git Metadata Project", "GIT3830")
    expect(page_text).to include(source.repository_full_name)
    expect(page_text).to include("release/main", "docs/operations")
    expect(page_text).to include("installation ID: 987654321")
    expect(page_text).to include("abcdef123456")
    expect(response.body).to include("ブランチ: release/main / 取込元パス: docs/operations")
    expect(response.body).not_to include("raw-source-secret-3830")
    expect(response.body).not_to include("vault/git/source-token-3830")
  end

  it "masks run summary and error diagnostics while preserving Git context" do
    sign_in_as(admin_user)
    project = create(:project, code: "GITRUN", name: "Git Run Project")
    source = create(
      :git_import_source,
      project:,
      repository_full_name: "matsuo-haruhito/docs-portal",
      branch: "main",
      source_path: "docs/git-runbook"
    )
    create_git_import_run!(
      git_import_source: source,
      status: :failed,
      summary_json: {
        "documents" => 1,
        "source_path" => "docs/git-runbook",
        "commit_sha" => "abcdef1234567890",
        "authorization" => "Bearer raw-summary-bearer-3830",
        "nested" => {
          "secret" => "raw-nested-secret-3830",
          "workspace_path" => "/home/deploy/private/repo/file.md"
        }
      },
      error_message: "Authorization: Bearer raw-error-bearer-3830 token=raw-error-token-3830 failed at /Users/alice/private/repo.md"
    )

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Git Run Project", "GITRUN")
    expect(page_text).to include("matsuo-haruhito/docs-portal", "main", "docs/git-runbook")
    expect(page_text).to include("commit: abcdef1234567890")
    expect(page_text).to include("summary_json のマスク済み詳細")
    expect(page_text).to include("error_message のマスク済み preview")
    expect(response.body).to include("[masked]")
    expect(response.body).to include("[path hidden]")
    expect(response.body).not_to include("raw-summary-bearer-3830")
    expect(response.body).not_to include("raw-nested-secret-3830")
    expect(response.body).not_to include("raw-error-bearer-3830")
    expect(response.body).not_to include("raw-error-token-3830")
    expect(response.body).not_to include("/home/deploy/private/repo/file.md")
    expect(response.body).not_to include("/Users/alice/private/repo.md")
  end
end
