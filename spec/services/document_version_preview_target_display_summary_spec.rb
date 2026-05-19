require "rails_helper"

RSpec.describe DocumentVersionPreviewTargetDisplaySummary do
  let(:version) { build_stubbed(:document_version) }
  let(:files) do
    {
      primary: build_stubbed(:document_file, file_name: "README.md"),
      attachment: build_stubbed(:document_file, file_name: "attachments/spec.pdf"),
      hidden: build_stubbed(:document_file, file_name: "hidden/private.pdf"),
      debug: build_stubbed(:document_file, file_name: "debug/raw.json"),
      grouped: build_stubbed(:document_file, file_name: "diagrams/flow.puml"),
      normal: build_stubbed(:document_file, file_name: "misc/note.txt")
    }
  end

  def classification(key, role:, group_name: nil, hidden: false, debug: false)
    DocumentVersionPreviewTargetClassifier::Classification.new(
      file: files.fetch(key),
      role:,
      group_name:,
      hidden:,
      debug:
    )
  end

  it "summarizes classifications by display bucket" do
    classifications = [
      classification(:primary, role: :primary),
      classification(:attachment, role: :attachment),
      classification(:hidden, role: :hidden, hidden: true),
      classification(:debug, role: :debug, debug: true),
      classification(:grouped, role: :grouped, group_name: "diagrams"),
      classification(:normal, role: :normal)
    ]

    summary = described_class.new(version, classifications:).call

    expect(summary).to be_present
    expect(summary.primary.map(&:tree_path)).to eq(["README.md"])
    expect(summary.attachments.map(&:tree_path)).to eq(["attachments/spec.pdf"])
    expect(summary.hidden.map(&:tree_path)).to eq(["hidden/private.pdf"])
    expect(summary.debug.map(&:tree_path)).to eq(["debug/raw.json"])
    expect(summary.groups.keys).to eq(["diagrams"])
    expect(summary.groups.fetch("diagrams").map(&:tree_path)).to eq(["diagrams/flow.puml"])
    expect(summary.normal.map(&:tree_path)).to eq(["misc/note.txt"])
  end

  it "is not present when every file is normal and ungrouped" do
    summary = described_class.new(
      version,
      classifications: [classification(:normal, role: :normal)]
    ).call

    expect(summary).not_to be_present
  end
end
