require "rails_helper"
require "tempfile"

RSpec.describe Mcp::DocumentPublish do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:oauth_application) do
    Doorkeeper::Application.create!(
      name: "公開エージェント",
      redirect_uri: "https://agent.example.com/callback",
      scopes: "documents:read documents:write documents:publish",
      confidential: false
    )
  end

  around do |example|
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
    example.run
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
  end

  before do
    allow(DocusaurusPreviewBuildJob).to receive(:enqueue_for).and_return(true)
    allow_any_instance_of(GeneratedFiles::ChangeEventNotifier).to receive(:notify).and_return([])
    allow_any_instance_of(NotificationEventPublisher).to receive(:publish_document_published!).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return(nil)
  end

  it "publishes a reviewed draft and replays the completed response idempotently" do
    result = ManualDocumentUpload.new(
      project:,
      actor: user,
      uploaded_file: uploaded_file("operation.md", "# 運用手順\n\n公開可能な本文です。"),
      source_path: "guides"
    ).call
    version = result.version
    preview = described_class.preview(
      user:,
      application: oauth_application,
      version_public_id: version.public_id
    )

    expect do
      @first_response = described_class.apply(
        user:,
        application: oauth_application,
        version_public_id: version.public_id,
        confirmation_token: preview.fetch(:confirmation_token),
        idempotency_key: "publish-request-001"
      )
    end.to change(McpMutationReceipt, :count).by(1)

    expect(version.reload).to be_published
    expect(version.document.reload.latest_version).to eq(version)
    expect(@first_response).to include(status: "published")

    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return("true")
    expect do
      replay = described_class.apply(
        user:,
        application: oauth_application,
        version_public_id: version.public_id,
        confirmation_token: preview.fetch(:confirmation_token),
        idempotency_key: "publish-request-001"
      )
      expect(replay).to eq(@first_response)
    end.not_to change { [McpMutationReceipt.count, version.reload.updated_at] }
  end

  def uploaded_file(name, content)
    tempfile = Tempfile.new([File.basename(name, ".*"), File.extname(name)])
    tempfile.write(content)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: name)
  end
end
