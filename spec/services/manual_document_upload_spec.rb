require "rails_helper"
require "tempfile"

RSpec.describe ManualDocumentUpload do
  around do |example|
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
    example.run
    FileUtils.rm_rf(DocumentFile.storage_root.join("manual_uploads"))
  end

  it "notifies a create file event after a new manual upload" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("decision_flow.yml", "flow: {}"),
      source_path: "storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data",
      change_event_notifier: notifier
    ).call

    expect(result.source_path).to eq("storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml")
    expect(notifier).to have_received(:notify).with(
      file_events: [
        {
          path: "storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml",
          operation: "create"
        }
      ],
      event_source: "manual_document_upload",
      metadata: hash_including(
        project_id: project.id,
        document_id: result.document.id,
        document_version_id: result.version.id,
        actor_id: actor.id
      )
    )
  end

  it "omits actor metadata when the upload actor is absent" do
    project = create(:project)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])

    result = described_class.new(
      project:,
      actor: nil,
      uploaded_file: uploaded_file("decision_flow.yml", "flow: {}"),
      source_path: "data",
      change_event_notifier: notifier
    ).call

    expect(notifier).to have_received(:notify).with(
      file_events: [{path: "data/decision_flow.yml", operation: "create"}],
      event_source: "manual_document_upload",
      metadata: hash_including(
        project_id: project.id,
        document_id: result.document.id,
        document_version_id: result.version.id
      )
    )
    expect(notifier).to have_received(:notify) do |payload|
      expect(payload[:metadata]).not_to have_key(:actor_id)
    end
  end

  it "adds a new manual version for an existing document instead of overwriting latest_version" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])

    first = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("decision_flow.yml", "flow: first"),
      source_path: "data",
      change_event_notifier: notifier
    ).call

    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    second = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("decision_flow.yml", "flow: second"),
      source_path: "data",
      target_document: first.document,
      change_event_notifier: notifier
    ).call

    expect(second.document).to eq(first.document)
    expect(first.document.reload.document_versions.count).to eq(2)
    expect(first.document.latest_version).to be_nil
    expect(second.version.version_label).to start_with("manual-")
    expect(notifier).to have_received(:notify).with(
      file_events: [{path: "data/decision_flow.yml", operation: "update"}],
      event_source: "manual_document_upload",
      metadata: hash_including(
        project_id: project.id,
        document_id: first.document.id,
        document_version_id: second.version.id,
        actor_id: actor.id
      )
    )
  end

  it "creates a sibling document when dropping a different file onto an existing document" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    original = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("guide.md", "# Guide", content_type: "text/markdown"),
      source_path: "docs/manuals",
      change_event_notifier: notifier
    ).call

    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    sibling = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("appendix.md", "# Appendix", content_type: "text/markdown"),
      target_document: original.document,
      change_event_notifier: notifier
    ).call

    expect(sibling.document).not_to eq(original.document)
    expect(sibling.source_path).to eq("docs/manuals/appendix.md")
    expect(notifier).to have_received(:notify).with(
      file_events: [{path: "docs/manuals/appendix.md", operation: "create"}],
      event_source: "manual_document_upload",
      metadata: hash_including(
        project_id: project.id,
        document_id: sibling.document.id,
        document_version_id: sibling.version.id,
        actor_id: actor.id
      )
    )
  end

  it "extracts markdown upload text for document search" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("guide.md", "# Guide\n\nSearchable manual upload body", content_type: "text/markdown"),
      source_path: "docs",
      change_event_notifier: notifier
    ).call

    expect(result.version.reload.search_body_text).to include("Searchable manual upload body")
  end

  it "uses the basename of uploaded file names" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("../secret.md", "# Secret", content_type: "text/markdown"),
      source_path: "docs",
      change_event_notifier: notifier
    ).call

    expect(result.source_path).to eq("docs/secret.md")
    expect(result.version.source_file_name).to eq("secret.md")
  end

  it "normalizes upload destination folders that stay inside the project tree" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("guide.md", "# Guide", content_type: "text/markdown"),
      source_path: "docs/../docs/manuals",
      change_event_notifier: notifier
    ).call

    expect(result.source_path).to eq("docs/manuals/guide.md")
  end

  it "rejects unsafe upload destination folders" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])

    expect do
      described_class.new(
        project:,
        actor:,
        uploaded_file: uploaded_file("guide.md", "# Guide", content_type: "text/markdown"),
        source_path: "../secret",
        change_event_notifier: notifier
      ).call
    end.to raise_error(ApplicationError::BadRequest, /アップロード先フォルダが不正です/)
  end

  it "rejects absolute and drive-letter upload destination folders" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])

    ["/secret", "C:/secret"].each do |source_path|
      expect do
        described_class.new(
          project:,
          actor:,
          uploaded_file: uploaded_file("guide.md", "# Guide", content_type: "text/markdown"),
          source_path:,
          change_event_notifier: notifier
        ).call
      end.to raise_error(ApplicationError::BadRequest, /アップロード先フォルダが不正です/)
    end
  end

  it "enqueues preview builds for uppercase markdown uploads" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("Guide.MDX", "# Guide", content_type: "text/markdown"),
      source_path: "docs",
      change_event_notifier: notifier
    ).call

    expect(result.source_path).to eq("docs/Guide.MDX")
    expect(result.version.preview_build_status).to eq("preview_queued")
    expect(DocusaurusPreviewBuildJob).to have_received(:perform_later).with(result.version.id)
  end

  it "does not enqueue preview builds for non-markdown uploads" do
    project = create(:project)
    actor = create(:user, :internal)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    allow(DocusaurusPreviewBuildJob).to receive(:perform_later)

    result = described_class.new(
      project:,
      actor:,
      uploaded_file: uploaded_file("guide.pdf", "%PDF", content_type: "application/pdf"),
      source_path: "docs",
      change_event_notifier: notifier
    ).call

    expect(result.source_path).to eq("docs/guide.pdf")
    expect(result.version.preview_build_status).not_to eq("preview_queued")
    expect(DocusaurusPreviewBuildJob).not_to have_received(:perform_later)
  end

  def uploaded_file(name, content, content_type: "text/yaml")
    tempfile = Tempfile.new([File.basename(name, ".*"), File.extname(name)])
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, content_type, original_filename: name)
  end
end