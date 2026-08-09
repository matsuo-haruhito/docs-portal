require "rails_helper"

RSpec.describe Mcp::DocumentRevision do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:oauth_application) do
    Doorkeeper::Application.create!(
      name: "改訂エージェント",
      redirect_uri: "https://agent.example.com/callback",
      scopes: "documents:read documents:write documents:publish",
      confidential: false
    )
  end
  let(:document) { create(:document, project:, source_authority: :docs_portal) }
  let!(:base_version) do
    create(:document_version, document:, status: :published).tap do |version|
      version.assign_source_path_metadata!(source_path: "guides/operation.md", snapshot_kind: "received_markdown")
      version.save!
      document.update!(latest_version: version)
    end
  end
  let(:attributes) do
    {
      document_public_id: document.public_id,
      body: "# 改訂版\n\n安全な更新です。",
      changelog_summary: "MCPによる改訂",
      metadata: { title: "改訂後タイトル" }
    }
  end

  around do |example|
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
    example.run
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
  end

  before do
    allow(DocusaurusPreviewBuildJob).to receive(:enqueue_for).and_return(true)
    allow_any_instance_of(GeneratedFiles::ChangeEventNotifier).to receive(:notify).and_return([])
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return(nil)
  end

  it "previews and applies an immutable draft revision idempotently" do
    preview = described_class.preview(user:, application: oauth_application, attributes:)

    expect(preview).to include(
      operation: "revise",
      document_public_id: document.public_id,
      base_version_public_id: base_version.public_id,
      source_path: "guides/operation.md"
    )

    expect do
      @first_response = described_class.apply(
        user:,
        application: oauth_application,
        attributes:,
        confirmation_token: preview.fetch(:confirmation_token),
        idempotency_key: "revision-request-001"
      )
    end.to change(DocumentVersion, :count).by(1)
      .and change(McpMutationReceipt, :count).by(1)

    new_version = DocumentVersion.find_by!(public_id: @first_response.fetch(:document_version_public_id))
    expect(new_version).to be_draft
    expect(new_version).not_to eq(base_version)
    expect(document.reload.latest_version).to eq(base_version)
    expect(document.title).to eq("改訂後タイトル")

    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return("true")
    expect do
      replay = described_class.apply(
        user:,
        application: oauth_application,
        attributes:,
        confirmation_token: preview.fetch(:confirmation_token),
        idempotency_key: "revision-request-001"
      )
      expect(replay).to eq(@first_response)
    end.not_to change { [DocumentVersion.count, McpMutationReceipt.count] }
  end

  it "routes externally authoritative documents away from direct revision" do
    document.update!(source_authority: :github)

    expect do
      described_class.preview(user:, application: oauth_application, attributes:)
    end.to raise_error(ApplicationError::BadRequest, /docs-portalが正本ではありません/)
  end

  it "allows preview but blocks apply during read-only maintenance" do
    preview = described_class.preview(user:, application: oauth_application, attributes:)
    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return("true")

    version_count = DocumentVersion.count
    expect do
      described_class.apply(
        user:,
        application: oauth_application,
        attributes:,
        confirmation_token: preview.fetch(:confirmation_token),
        idempotency_key: "revision-request-002"
      )
    end.to raise_error(ApplicationError::BadRequest, /メンテナンス中/)
    expect(DocumentVersion.count).to eq(version_count)
  end
end
