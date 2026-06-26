require "rails_helper"

RSpec.describe "Document version rollbacks", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "ROLLBACK", name: "Rollback Project") }
  let(:document) { create(:document, project:, title: "Rollback Document", slug: "rollback-document") }

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
      .and not_change { document.reload.archived? }

    expect(response).to redirect_to(document_version_path(previous_version))
    expect(flash[:notice]).to eq("直前の版へロールバックしました。")
    expect(version.reload.changelog_summary).to include("Rolled back manual upload")
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

  it "forbids an external user even when the version is visible" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, :user_scoped, document:, user: external_user, access_level: :view)
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 1.day.ago)
    document.update!(latest_version: version)

    sign_in_as(external_user)

    expect do
      rollback(version)
    end.to not_change { version.reload.status }
      .and not_change { document.reload.latest_version_id }
      .and not_change { document.reload.archived? }

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a manual upload version that is not the latest version" do
    version = create_manual_upload_version(version_label: "v1.0.0", created_at: 2.days.ago)
    latest_version = create_version(
      version_label: "v1.1.0",
      source_commit_hash: "git-import",
      created_at: 1.day.ago
    )
    document.update!(latest_version: latest_version)

    sign_in_as(internal_user)

    expect do
      rollback(version)
    end.to not_change { version.reload.status }
      .and not_change { document.reload.latest_version_id }
      .and not_change { document.reload.archived? }

    expect(response).to redirect_to(document_version_path(version))
    expect(flash[:alert]).to eq("最新の版だけ取り消せます。")
  end

  it "rejects a latest version that did not come from manual upload" do
    version = create_version(
      version_label: "v1.0.0",
      source_commit_hash: "git-import",
      created_at: 1.day.ago
    )
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    expect do
      rollback(version)
    end.to not_change { version.reload.status }
      .and not_change { document.reload.latest_version_id }
      .and not_change { document.reload.archived? }

    expect(response).to redirect_to(document_version_path(version))
    expect(flash[:alert]).to eq("手動アップロード版だけ取り消せます。")
  end
end
