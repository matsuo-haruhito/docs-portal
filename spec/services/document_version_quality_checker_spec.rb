require "rails_helper"
require "fileutils"

RSpec.describe DocumentVersionQualityChecker do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Operation Manual") }
  let(:version) { create(:document_version, document:, source_relative_path: "docs/manual.md") }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "quality-checker"))
    FileUtils.rm_rf(Rails.root.join("storage", "docs_sites", version.id.to_s)) if version&.id
  end

  def create_file_record(scan_status: :scan_clean, write_file: true, file_name: "manual.pdf", content_type: "application/pdf", body: "%PDF-1.4")
    storage_key = "spec/quality-checker/#{SecureRandom.hex(8)}/#{file_name}"
    file = create(
      :document_file,
      document_version: version,
      file_name:,
      content_type:,
      storage_key:,
      file_size: 12,
      scan_status:
    )

    if write_file
      FileUtils.mkdir_p(file.absolute_path.dirname)
      File.binwrite(file.absolute_path, body)
    end

    file
  end

  def create_markdown_source(body:, file_name: "manual.md")
    storage_key = "spec/quality-checker/#{SecureRandom.hex(8)}/#{file_name}"
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

  it "passes when required metadata and attached clean files are present" do
    create_file_record

    result = described_class.new(version).call

    expect(result).to be_pass
    expect(result.errors).to be_empty
    expect(result.checks.map(&:key)).to include(:document_file_exists, :document_file_scan)
  end

  it "reports missing attached files as errors" do
    create_file_record(write_file: false)

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).to include(:document_file_missing)
  end

  it "reports pending scans as warnings" do
    create_file_record(scan_status: :scan_pending)

    result = described_class.new(version).call

    expect(result.warnings.map(&:key)).to include(:document_file_scan)
  end

  it "reports unsafe scan statuses as errors" do
    create_file_record(scan_status: :scan_infected)

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).to include(:document_file_scan)
  end

  it "reports preview build queued as a warning" do
    version.mark_preview_build_queued!
    create_file_record

    result = described_class.new(version).call

    check = result.warnings.find { _1.key == :preview_build_status }
    expect(check.message).to eq("Preview build is queued")
    expect(check.detail).to include("preview_queued")
  end

  it "reports preview build running as a warning" do
    version.mark_preview_build_running!
    create_file_record

    result = described_class.new(version).call

    check = result.warnings.find { _1.key == :preview_build_status }
    expect(check.message).to eq("Preview build is running")
    expect(check.detail).to include("preview_running")
  end

  it "reports preview build failure as an error" do
    version.mark_preview_build_failed!("renderer failed")
    create_file_record

    result = described_class.new(version).call

    check = result.errors.find { _1.key == :preview_build_status }
    expect(check.message).to eq("Preview build failed")
    expect(check.detail).to include("renderer failed")
  end

  it "reports preview build success as info" do
    version.mark_preview_build_succeeded!
    create_file_record

    result = described_class.new(version).call

    check = result.infos.find { _1.key == :preview_build_status }
    expect(check.message).to eq("Preview build succeeded")
    expect(check.detail).to include("preview_succeeded")
  end

  it "reports missing rendered site entries as errors" do
    version.update!(site_build_path: "manual")
    create_file_record

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).to include(:rendered_site)
  end

  it "reports unbuilt markdown preview as a warning" do
    create_file_record

    result = described_class.new(version).call

    warning = result.warnings.find { _1.key == :rendered_site }
    expect(warning.message).to eq("Markdown preview site is not built yet")
    expect(warning.detail).to eq("docs/manual.md")
  end

  it "does not report unbuilt preview warning for non-markdown sources" do
    version.update!(source_relative_path: "docs/manual.pdf")
    create_file_record

    result = described_class.new(version).call

    expect(result.warnings.select { _1.key == :rendered_site }).to be_empty
    expect(result.checks.select { _1.key == :preview_build_status }).to be_empty
  end

  it "reports internal-only wording as a warning" do
    version.update!(search_body_text: "This document is internal_only.")
    create_file_record

    result = described_class.new(version).call

    expect(result.warnings.map(&:key)).to include(:internal_only_text)
  end

  it "reports missing markdown link, image, and attachment targets as errors" do
    create_markdown_source(
      body: <<~MD
        [Guide](missing-guide.md)
        ![Architecture](missing-diagram.png)
        [Handout](missing-handout.pdf)
      MD
    )

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).to include(
      :markdown_link_missing,
      :markdown_image_missing,
      :markdown_attachment_missing
    )
  end

  it "accepts markdown references that point at existing project docs and attached files" do
    create(:document_version, document: create(:document, project:, title: "Guide"), source_relative_path: "docs/guide.md")
    create_markdown_source(
      body: <<~MD
        [Guide](guide.md)
        ![Architecture](diagram.png)
        [Handout](handout.pdf)
      MD
    )
    create_file_record(file_name: "diagram.png", content_type: "image/png", body: "PNG")
    create_file_record(file_name: "handout.pdf")

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).not_to include(
      :markdown_link_missing,
      :markdown_image_missing,
      :markdown_attachment_missing
    )
  end
end
