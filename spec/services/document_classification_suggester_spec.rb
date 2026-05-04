require "rails_helper"
require "tempfile"

RSpec.describe DocumentClassificationSuggester do
  def write_rules(content)
    file = Tempfile.new(["classification-rules", ".yml"])
    file.write(content)
    file.flush
    file
  end

  after do
    @rules_file&.close
    @rules_file&.unlink
  end

  it "suggests classification attributes from source path rules" do
    @rules_file = write_rules(<<~YAML)
      rules:
        - name: submitted
          pattern: "submitted"
          category: spec
          snapshot_kind: submitted
          visibility_policy: restricted_external
    YAML

    suggestion = described_class.new(rules_path: @rules_file.path).suggest(
      source_path: "docs/submitted/manual.md"
    )

    expect(suggestion.attributes).to include(
      category: "spec",
      snapshot_kind: "submitted",
      visibility_policy: "restricted_external"
    )
    expect(suggestion.matched_rules).to eq(["submitted"])
  end

  it "suggests document kind from file extension" do
    @rules_file = write_rules(<<~YAML)
      extension_rules:
        pdf:
          document_kind: pdf
    YAML

    suggestion = described_class.new(rules_path: @rules_file.path).suggest(
      source_path: "docs/specification.pdf"
    )

    expect(suggestion.attributes).to include(document_kind: "pdf")
  end

  it "lets frontmatter override rule and extension suggestions" do
    @rules_file = write_rules(<<~YAML)
      rules:
        - name: meeting_note
          pattern: "meeting"
          category: meeting_note
          document_kind: markdown
      extension_rules:
        md:
          document_kind: markdown
    YAML

    suggestion = described_class.new(rules_path: @rules_file.path).suggest(
      source_path: "docs/meeting.md",
      frontmatter: {
        "category" => "contract",
        "document_kind" => "pdf",
        "visibility_policy" => "internal_only"
      }
    )

    expect(suggestion.attributes).to include(
      category: "contract",
      document_kind: "pdf",
      visibility_policy: "internal_only"
    )
  end

  it "returns an empty suggestion when no rules match" do
    @rules_file = write_rules(<<~YAML)
      rules:
        - name: submitted
          pattern: "submitted"
          category: spec
    YAML

    suggestion = described_class.new(rules_path: @rules_file.path).suggest(
      source_path: "docs/overview.unknown"
    )

    expect(suggestion).to be_empty
    expect(suggestion.matched_rules).to be_empty
  end
end
