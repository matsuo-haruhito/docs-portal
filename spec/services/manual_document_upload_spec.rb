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

  it "notifies an update file event after uploading a new version for an existing document" do
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
    expect(result.version.preview_build_status).to eq("queued")
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
    expect(result.version.preview_build_status).not_to eq("queued")
    expect(DocusaurusPreviewBuildJob).not_to have_received(:perform_later)
  end

  def uploaded_file(name, content, content_type: "text/yaml")
    tempfile = Tempfile.new([File.basename(name, ".*"), File.extname(name)])
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, content_type, original_filename: name)
  end
end