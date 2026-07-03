require "rails_helper"

RSpec.describe "Admin dashboard external sync failure digest", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows a read-only Markdown digest for external folder sync failure candidates" do
    source = create_source(name: "Drive Alpha")
    latest_failure_at = 30.minutes.ago.change(usec: 0)
    create_run(
      source: source,
      status: :partial,
      started_at: latest_failure_at,
      error_message: "Authorization: Bearer raw-token token=secret /home/app/private https://example.test/file?X-Amz-Signature=abc"
    )
    create_run(source: source, status: :failed, started_at: 45.minutes.ago, error_message: "older failure")
    create_run(source: source, status: :failed, started_at: 1.hour.ago, error_message: "oldest failure")

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("外部フォルダ同期")
    expect(page_text).to include("継続失敗候補: 1 件")
    expect(page_text).to include("Drive Alpha")
    expect(page_text).to include("連続 failed / partial: 3 件")
    expect(page_text).to include("外部フォルダ同期継続失敗候補 digest")
    expect(page_text).to include("通知済み、ack、SLA、自動 retry、provider 正常判定の状態としては扱いません")

    textarea = parsed_html.at_css(%(textarea[name="external_sync_failure_digest_markdown"]))
    expect(textarea).to be_present
    digest = textarea.text

    expect(digest).to include("## 外部フォルダ同期継続失敗候補 digest")
    expect(digest).to include("- source: Drive Alpha")
    expect(digest).to include("  - provider: google_drive")
    expect(digest).to include("  - project: #{source.project.code} #{source.project.name}")
    expect(digest).to include("  - consecutive_failed_or_partial: 3")
    expect(digest).to include("  - last_failed_at: #{(latest_failure_at + 1.minute).iso8601}")
    expect(digest).to include("  - source_path: /admin/external_folder_sync_sources/#{source.to_param}")
    expect(digest).to include("Runbook: docs/外部フォルダ同期継続失敗候補runbook.md")
    expect(digest).to include("All error sources: /admin/external_folder_sync_sources?review=errors")
    expect(digest).to include("Authorization: Bearer [FILTERED]")
    expect(digest).to include("token=[FILTERED]")
    expect(digest).to include("[path omitted]")
    expect(digest).to include("[url omitted]")
    expect(digest).not_to include("raw-token")
    expect(digest).not_to include("secret")
    expect(digest).not_to include("/home/app/private")
    expect(digest).not_to include("X-Amz-Signature=abc")
    expect(response.body).not_to include("raw-token")
    expect(response.body).not_to include("/home/app/private")
    expect(response.body).not_to include("X-Amz-Signature=abc")
  end

  def create_source(name: "Drive source", external_folder_id: "folder-alpha")
    ExternalFolderSyncSource.create!(
      project: create(:project),
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: name,
      folder_url: "https://drive.google.com/drive/folders/#{external_folder_id}",
      external_folder_id: external_folder_id,
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      auth_config: "{}",
      enabled: true
    )
  end

  def create_run(source:, status:, started_at:, error_message: "boom")
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: source,
      status: status,
      mode: :dry_run,
      started_at: started_at,
      finished_at: started_at + 1.minute,
      error_message: %i[failed partial].include?(status.to_sym) ? error_message : nil
    )
  end
end
