require "rails_helper"

RSpec.describe GeneratedFiles::OutputWriters::DocumentVersion do
  around do |example|
    storage_root = DocumentFile.storage_root
    FileUtils.rm_rf(storage_root.join("generated_files"))
    example.run
    FileUtils.rm_rf(storage_root.join("generated_files"))
  end

  it "writes artifacts as a published document version with document files" do
    project = Project.create!(code: "generated-output", name: "Generated Output")
    artifacts = [
      GeneratedFiles::Artifact.new(
        path: "generated/decision-flow.md",
        content: "# Generated Flow\n\n本文",
        content_type: "text/markdown"
      ),
      GeneratedFiles::Artifact.new(
        path: "generated/decision-flow.puml",
        content: "@startuml\n@enduml",
        content_type: "text/vnd.plantuml"
      )
    ]

    result = described_class.new(
      project_code: project.code,
      document_slug: "ai-usecase-generated-flow",
      document_title: "AI活用判断フロー生成結果",
      document_category: "other",
      document_kind: "mixed",
      visibility_policy: "internal_only",
      importance_level: "reference",
      version_label_prefix: "generated-flow",
      source_identifier: "generated:ai_usecase_decision_flow"
    ).write(artifacts)

    document = project.documents.find_by!(slug: "ai-usecase-generated-flow")
    version = document.latest_version

    expect(result).to eq(["document_versions/#{version.public_id}"])
    expect(document.title).to eq("AI活用判断フロー生成結果")
    expect(version).to be_published
    expect(version.version_label).to start_with("generated-flow-")
    expect(version.source_commit_hash).to eq("generated:ai_usecase_decision_flow")
    expect(version.source_relative_path).to eq("generated/decision-flow.md")
    expect(version.search_body_text).to include("Generated Flow")

    files = version.document_files.order(:sort_order).to_a
    expect(files.map(&:file_name)).to eq([
      "generated/decision-flow.md",
      "generated/decision-flow.puml"
    ])
    expect(files.map(&:content_type)).to eq(["text/markdown", "text/vnd.plantuml"])
    expect(files.map(&:file_size)).to eq(artifacts.map { _1.content.bytesize })
    expect(files.map(&:scan_status)).to all(eq("scan_pending"))

    expect(files.first.absolute_path.read).to eq("# Generated Flow\n\n本文")
    expect(files.second.absolute_path.read).to eq("@startuml\n@enduml")
  end

  it "creates the output project when explicitly allowed" do
    result = described_class.new(
      project_code: "GENERATED_AI_USECASES",
      project_name: "AI活用生成ドキュメント",
      project_description: "AI活用判断フローなどの生成結果",
      create_project_if_missing: true,
      document_slug: "ai-usecase-generated-flow",
      document_title: "AI活用判断フロー生成結果"
    ).write([
      GeneratedFiles::Artifact.new(
        path: "generated/decision-flow.md",
        content: "# Generated Flow",
        content_type: "text/markdown"
      )
    ])

    project = Project.find_by!(code: "GENERATED_AI_USECASES")
    document = project.documents.find_by!(slug: "ai-usecase-generated-flow")
    version = document.latest_version

    expect(result).to eq(["document_versions/#{version.public_id}"])
    expect(project.name).to eq("AI活用生成ドキュメント")
    expect(project.description).to eq("AI活用判断フローなどの生成結果")
    expect(document.title).to eq("AI活用判断フロー生成結果")
    expect(version).to be_published
  end

  it "raises when the output project is missing and auto creation is disabled" do
    expect do
      described_class.new(
        project_code: "MISSING_GENERATED_OUTPUT",
        document_slug: "missing-generated-flow",
        document_title: "Missing"
      ).write([
        GeneratedFiles::Artifact.new(
          path: "generated/missing.md",
          content: "missing",
          content_type: "text/markdown"
        )
      ])
    end.to raise_error(ActiveRecord::RecordNotFound, /Generated output project not found/)
  end

  it "creates a new version on each write and keeps the same document" do
    project = Project.create!(code: "generated-output-repeat", name: "Generated Output Repeat")
    writer = described_class.new(
      project_code: project.code,
      document_slug: "repeat-generated-flow",
      document_title: "繰り返し生成結果"
    )

    2.times do |index|
      writer.write([
        GeneratedFiles::Artifact.new(
          path: "generated/repeat.md",
          content: "content #{index}",
          content_type: "text/markdown"
        )
      ])
    end

    document = project.documents.find_by!(slug: "repeat-generated-flow")
    expect(document.document_versions.count).to eq(2)
    expect(document.latest_version.document_files.first.absolute_path.read).to eq("content 1")
  end
end
