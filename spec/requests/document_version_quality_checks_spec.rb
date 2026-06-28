require "rails_helper"

RSpec.describe "Document version quality checks", type: :request do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      search_body_text: "internal_only token=super-secret /Users/alice/private/manual.md attachment-full-metadata"
    )
  end
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company: create(:company)) }

  def parsed_json
    JSON.parse(response.body)
  end

  before do
    document.update!(latest_version: version)
  end

  it "shows the quality check to internal users in html/json/markdown" do
    sign_in_as(internal_user)

    get document_version_quality_check_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("品質チェック")
    expect(response.body).to include("fail は error がある状態です")
    expect(response.body).to include("error がある場合は下の一覧の error 行を先に確認してください")
    expect(response.body).to include("warning は確認が必要な注意、info は参考情報")
    expect(response.body).to include("自動 fail や通知済み状態ではありません")
    expect(response.body).to include("JSON / Markdown は handoff や evidence 用の read-only export")
    expect(response.body).to include("この画面から品質チェック結果、版、公開状態は変更されません")
    expect(response.body).to include("Check table filter")
    expect(response.body).to include("この filter は下の check table だけに適用されます")
    expect(response.body).to include("Preview と JSON / Markdown export は全件の read-only evidence のままです")
    expect(response.body).to include("internal_only_text")

    get document_version_quality_check_path(version, format: :json)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    payload = parsed_json
    expect(payload).to include(
      "valid" => true,
      "document_version" => a_hash_including(
        "public_id" => version.public_id,
        "version_label" => "v1.0.0",
        "status" => "published",
        "document" => a_hash_including(
          "public_id" => document.public_id,
          "title" => "Manual",
          "slug" => "manual",
          "visibility_policy" => "restricted_external"
        )
      ),
      "summary" => a_hash_including(
        "error_count" => 0,
        "warning_count" => 2,
        "info_count" => a_value >= 1
      )
    )
    expect(payload.fetch("checks")).to include(
      a_hash_including(
        "key" => "document_files",
        "severity" => "warning",
        "message" => "No document files are attached",
        "detail" => nil
      ),
      a_hash_including(
        "key" => "internal_only_text",
        "severity" => "warning",
        "message" => "Document contains internal-only wording"
      )
    )
    expect(response.body).not_to include("token=super-secret")
    expect(response.body).not_to include("/Users/alice/private/manual.md")
    expect(response.body).not_to include("attachment-full-metadata")

    get document_version_quality_check_path(version, format: :md)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Quality check: Manual")
    expect(response.body).to include("- version: v1.0.0")
    expect(response.body).to include("- result: pass")
    expect(response.body).to include("- warnings: 2")
    expect(response.body).to include("- **Warning** `document_files`: No document files are attached")
    expect(response.body).not_to include("token=super-secret")
    expect(response.body).not_to include("/Users/alice/private/manual.md")
    expect(response.body).not_to include("attachment-full-metadata")
  end

  it "filters the html check table by severity and key without changing exports" do
    sign_in_as(internal_user)

    get document_version_quality_check_path(version, severity: "warning")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No document files are attached")
    expect(response.body).to include("Document contains internal-only wording")
    expect(response.body).to include("severity")
    expect(response.body).to include("warning")
    expect(response.body).to include("Preview と JSON / Markdown export は全件の read-only evidence のままです")

    get document_version_quality_check_path(version, key: "internal_only_text")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Document contains internal-only wording")
    expect(response.body).not_to include("No document files are attached")

    get document_version_quality_check_path(version, key: "internal_only_text", format: :json)
    expect(response).to have_http_status(:ok)
    payload = parsed_json
    expect(payload.fetch("checks")).to include(
      a_hash_including(
        "key" => "document_files",
        "message" => "No document files are attached"
      ),
      a_hash_including(
        "key" => "internal_only_text",
        "message" => "Document contains internal-only wording"
      )
    )
  end

  it "falls back safely for unsupported quality check filter values" do
    sign_in_as(internal_user)

    get document_version_quality_check_path(version, severity: "critical", key: "missing_key")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No document files are attached")
    expect(response.body).to include("Document contains internal-only wording")
    expect(response.body).not_to include("critical")
    expect(response.body).not_to include("missing_key")
  end

  it "highlights preview quality checks in html" do
    version.assign_source_path_metadata!(source_path: "docs/manual.md", snapshot_kind: "received_markdown")
    version.mark_preview_build_queued!
    sign_in_as(internal_user)

    get document_version_quality_check_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Preview")
    expect(response.body).to include("rendered site と build status の warning / error 抜粋です")
    expect(response.body).to include("全件確認の正本ではないため、すべての check は下の一覧で確認してください")
    expect(response.body).to include("Preview build is queued")
    expect(response.body).to include("Markdown preview site is not built yet")
    expect(response.body).to include("docs/manual.md")
  end

  it "forbids external users from html/json/markdown exports" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    [
      document_version_quality_check_path(version),
      document_version_quality_check_path(version, format: :json),
      document_version_quality_check_path(version, format: :md)
    ].each do |path|
      get path

      expect(response).to have_http_status(:forbidden)
    end
  end

  it "redirects unauthenticated users before exposing html/json/markdown exports" do
    [
      document_version_quality_check_path(version),
      document_version_quality_check_path(version, format: :json),
      document_version_quality_check_path(version, format: :md)
    ].each do |path|
      get path

      expect(response).to redirect_to(new_session_path)
    end
  end
end
