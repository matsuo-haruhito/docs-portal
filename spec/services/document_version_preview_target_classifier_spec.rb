require "rails_helper"

RSpec.describe DocumentVersionPreviewTargetClassifier do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def file(name, sort_order: 0)
    build(:document_file, document_version: version, file_name: name, sort_order:)
  end

  def metadata_result(metadata)
    DocumentVersionPreviewTargetMetadata::Result.new(source_file: nil, metadata:, warnings: [])
  end

  it "classifies primary, attachment, hidden, debug, grouped, and normal files" do
    files = [
      file("README.md", sort_order: 0),
      file("attachments/spec.pdf", sort_order: 1),
      file("hidden/private.pdf", sort_order: 2),
      file("debug/raw.json", sort_order: 3),
      file("diagrams/flow.puml", sort_order: 4),
      file("misc/note.txt", sort_order: 5)
    ]
    allow(version).to receive_message_chain(:document_files, :order, :to_a).and_return(files)

    metadata = metadata_result(
      "primary" => ["README.md"],
      "attachments" => ["attachments/spec.pdf"],
      "hidden" => ["hidden/private.pdf"],
      "debug" => ["debug/raw.json"],
      "groups" => { "diagrams" => ["diagrams/flow.puml"] }
    )

    classifications = described_class.new(version, metadata:).call
    by_path = classifications.index_by(&:tree_path)

    expect(by_path["README.md"]).to be_primary
    expect(by_path["attachments/spec.pdf"]).to be_attachment
    expect(by_path["hidden/private.pdf"].role).to eq(:hidden)
    expect(by_path["hidden/private.pdf"]).to be_hidden
    expect(by_path["hidden/private.pdf"]).not_to be_visible
    expect(by_path["debug/raw.json"].role).to eq(:debug)
    expect(by_path["debug/raw.json"]).to be_debug
    expect(by_path["diagrams/flow.puml"].role).to eq(:grouped)
    expect(by_path["diagrams/flow.puml"].group_name).to eq("diagrams")
    expect(by_path["misc/note.txt"].role).to eq(:normal)
  end

  it "keeps primary role precedence over grouped metadata" do
    primary = file("README.md")
    allow(version).to receive_message_chain(:document_files, :order, :to_a).and_return([primary])

    metadata = metadata_result(
      "primary" => ["README.md"],
      "groups" => { "docs" => ["README.md"] }
    )

    classification = described_class.new(version, metadata:).call.first

    expect(classification).to be_primary
    expect(classification.group_name).to eq("docs")
  end

  it "uses document version metadata when metadata is not provided" do
    source = file("manual.md")
    allow(version).to receive_message_chain(:document_files, :order, :to_a).and_return([source])
    allow(DocumentVersionPreviewTargetMetadata).to receive(:new).with(version).and_return(
      instance_double(DocumentVersionPreviewTargetMetadata, call: metadata_result("primary" => ["manual.md"]))
    )

    classification = described_class.new(version).call.first

    expect(classification).to be_primary
  end
end
