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

  def create_file_record(scan_status: :scan_clean, write_file: true, file_name: "manual.pdf")
    storage_key = "spec/quality-checker/#{SecureRandom.hex(8)}/#{file_name}"
    file = create(
      :document_file,
      document_version: version,
      file_name:,
      content_type: "application/pdf",
      storage_key:,
      file_size: 12,
      scan_status:
    )

    if write_file
      FileUtils.mkdir_p(file.absolute_path.dirname)
      File.binwrite(file.absolute_path, "%PDF-1.4")
    end

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

  it "reports missing rendered site entries as errors" do
    version.update!(site_build_path: "manual")
    create_file_record

    result = described_class.new(version).call

    expect(result.errors.map(&:key)).to include(:rendered_site)
  end

  it "reports internal-only wording as a warning" do
    version.update!(search_body_text: "This document is internal_only.")
    create_file_record

    result = described_class.new(version).call

    expect(result.warnings.map(&:key)).to include(:internal_only_text)
  end
end
