require "rails_helper"
require "fileutils"

RSpec.describe "DocumentVersionQuality preview target metadata rendering" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Operation Manual", slug: "operation-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "quality-preview-target-rendering"))
  end

  def create_markdown_source(body:)
    storage_key = "spec/quality-preview-target-rendering/#{SecureRandom.hex(8)}/manual.md"
    file = create(
      :document_file,
      document_version: version,
      file_name: "manual.md",
      content_type: "text/markdown",
      storage_key:,
      file_size: body.bytesize,
      scan_status: :scan_clean
    )

    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, body)
    file
  end

  def quality_result
    create_markdown_source(
      body: <<~MD
        ---
        preview_targets:
          attachments:
            - missing.pdf
        ---

        # Manual
      MD
    )

    DocumentVersionQualityChecker.new(version).call
  end

  it "renders preview target metadata warnings in the stable hash" do
    hash = DocumentVersionQualityCheckHash.new(quality_result).call

    expect(hash[:checks]).to include(
      include(
        key: :preview_target_metadata,
        severity: :warning,
        detail: "missing.pdf"
      )
    )
  end

  it "renders preview target metadata warnings in markdown" do
    markdown = DocumentVersionQualityCheckMarkdown.new(quality_result).call

    expect(markdown).to include("**Warning** `preview_target_metadata`")
    expect(markdown).to include("missing.pdf")
  end
end
