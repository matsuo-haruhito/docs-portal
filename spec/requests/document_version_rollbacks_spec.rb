require "rails_helper"

RSpec.describe "Document version rollbacks", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "ROLLBACK", name: "Rollback Project") }
  let(:document) { create(:document, project:, title: "Rollback Document", slug: "rollback-document") }

  around do |example|
    original_read_only_maintenance = ENV.fetch("READ_ONLY_MAINTENANCE", nil)
    example.run
  ensure
    if original_read_only_maintenance.nil?
      ENV.delete("READ_ONLY_MAINTENANCE")
    else
      ENV["READ_ONLY_MAINTENANCE"] = original_read_only_maintenance
    end
  end

  def create_version(version_label:, source_commit_hash:, created_at:, status: :published)
    create(
      :document_version,
      document:,
      version_label:,
      status:,
      source_commit_hash:,
      created_at:,
      updated_at: created_at
    )
  end

  def create_manual_upload_version(version_label:, created_at:)
    create_version(
      version_label:,
      source_commit_hash: DocumentVersionRollback::MANUAL_UPLOAD_SOURCE,
      created_at:
    )
  end

  def rollback(version)
    post document_version_rollback_path(version)
  end

  def rollback_state(version)
    [version.reload.status, document.reload.latest_version_id, document.archived?]
  end

  it "rolls back the latest manual upload to the previous published version" do
    previous_version = create_version(
      version_label: "v1.0.0",
      source_commit_hash: "git-import",
      created_at: 2.days.ago
    )
    version = create_manual_upload_version(version_label: "v1.1.0", created_at: 1.day.ago)
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    expect do
      rollback(version)
    end.to change { version.reload.status }.from("published").to("archived")
      .and change { document.reload.latest_version_id }.from(version.id).to(previous_version.id)

    aggregate_failures do
      expect(document.reload).not_to be_archived
      expect(response).to redirect_to(document_version_path(previous_version))
      expect(flash[:notice]).to eq("直前の版へロールバックしました。")
      expect(version.reload.changelog_summary).to include("Rolled back manual upload")
    end
  end

  it "archives the document when no previous published version exists" do
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 1.day.ago)
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    expect do
      rollback(version)
    end.to change { version.reload.status }.from("published").to("archived")
      .and change { document.reload.latest_version_id }.from(version.id).to(nil)
      .and change { document.reload.archived? }.from(false).to(true)

    expect(response).to redirect_to(project_documents_path(project))
    expect(flash[:notice]).to eq("アップロードした文書を取り消し、文書をアーカイブしました。")
  end

  it "does not run rollback during read-only maintenance" do
    previous_version = create_version(
      version_label: "v1.0.0",
      source_commit_hash: "git-import",
      created_at: 2.days.ago
    )
    version = create_manual_upload_version(version_label: "v1.1.0", created_at: 1.day.ago)
    document.update!(latest_version: version)
    before_state = rollback_state(version)
    allow(DocumentVersionRollback).to receive(:new).and_call_original
    ENV["READ_ONLY_MAINTENANCE"] = "1"

    sign_in_as(internal_user)
    rollback(version)

    aggregate_failures do
      expect(rollback_state(version)).to eq(before_state)
      expect(document.reload.latest_version).to eq(version)
      expect(previous_version.reload).to be_published
      expect(DocumentVersionRollback).not_to have_received(:new)
      expect(response).to redirect_to(document_version_path(version))
      expect(flash[:alert]).to eq("メンテナンス中のため文書版の取り消しは停止しています。版詳細、差分、添付確認は閲覧できます。")
    end
  end

  it "keeps version detail readable during read-only maintenance" do
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 1.day.ago)
    document.update!(latest_version: version)
    ENV["READ_ONLY_MAINTENANCE"] = "1"

    sign_in_as(internal_user)
    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rollback Document")
    expect(response.body).to include("v1.0.0")
  end

  it "forbids an external user even when the version is visible" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, :user_scoped, document:, user: external_user, access_level: :view)
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 1.day.ago)
    document.update!(latest_version: version)
    before_state = rollback_state(version)

    sign_in_as(external_user)
    rollback(version)

    aggregate_failures do
      expect(rollback_state(version)).to eq(before_state)
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "rejects a manual upload version that is not the latest version" do
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 2.days.ago)
    latest_version = create_version(
      version_label: "v1.1.0",
      source_commit_hash: "git-import",
      created_at: 1.day.ago
    )
    document.update!(latest_version: latest_version)
    before_state = rollback_state(version)

    sign_in_as(internal_user)
    rollback(version)

    aggregate_failures do
      expect(rollback_state(version)).to eq(before_state)
      expect(response).to redirect_to(document_version_path(version))
      expect(flash[:alert]).to eq("最新の版だけ取り消せます。")
    end
  end

  it "rejects a latest version that did not come from manual upload" do
    version = create_version(
      version_label: "v1.0.0",
      source_commit_hash: "git-import",
      created_at: 1.day.ago
    )
    document.update!(latest_version: version)
    before_state = rollback_state(version)

    sign_in_as(internal_user)
    rollback(version)

    aggregate_failures do
      expect(rollback_state(version)).to eq(before_state)
      expect(response).to redirect_to(document_version_path(version))
      expect(flash[:alert]).to eq("手動アップロード版だけ取り消せます。")
    end
  end
end
