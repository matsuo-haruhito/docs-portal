require "rails_helper"
require "fileutils"

RSpec.describe "DocumentVersionQuality preview target metadata" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Operation Manual") }
  let(:version) { create(:document_version, document:, source_relative_path: "docs/manual.md") }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "quality-preview-targets"))
  end

  def create_markdown_source(body:, file_name: "manual.md")
    storage_key = "spec/quality-preview-targets/#{SecureRandom.hex(8)}/#{file_name}"
    file = create(
      :document_file,
      document_version: version,
      file_name:,
      content_type: "text/markdown",
      storage_key:,
      file_size: body.bytesize,
      scan_status: :scan_clean
    )

    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, body)
    file
  end

  it "reports preview target metadata source as info" do
    create_markdown_source(
      body: <<~MD
        ---
        preview_targets:
          primary: manual.md
        ---

        # Manual
      MD
    )

    result = DocumentVersionQualityChecker.new(version).call

    check = result.infos.find { _1.key == :preview_target_metadata }
    expect(check.message).to eq("Preview target metadata source is set")
    expect(check.detail).to eq("manual.md")
  end

  it "reports preview target metadata warnings" do
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

    result = DocumentVersionQualityChecker.new(version).call

    check = result.warnings.find { _1.key == :preview_target_metadata }
    expect(check.message).to include("missing.pdf")
    expect(check.detail).to eq("missing.pdf")
  end
end
