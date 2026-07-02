# frozen_string_literal: true

require "rails_helper"
require "fileutils"

require Rails.root.join("db/seeds/support/external_sample_validator").to_s

RSpec.describe SeedSupport::ExternalSampleValidator do
  def dry_run_payload(root, max_attachment_bytes: described_class::DEFAULT_MAX_ATTACHMENT_BYTES)
    described_class.new(root:, max_attachment_bytes:).call.to_h
  end

  def prepare_sample_root(name)
    root = Rails.root.join("tmp/spec/external_samples/#{name}")
    FileUtils.rm_rf(root)

    source_dir = root.join("sample-set/site")
    FileUtils.mkdir_p(source_dir)
    File.write(source_dir.join("index.md"), "# Sample\n")

    [root, source_dir]
  end

  def document_candidate(source_dir:, markdown_source_file:, attachment_files: [], title: "Sample", slug: "sample", version_label: "current")
    {
      project_code: "EXT_SAMPLE_SET_SITE",
      project_name: "sample-set / site",
      title:,
      slug:,
      version_label:,
      source_dir:,
      markdown_source_file:,
      markdown_logical_relative_path: Pathname(markdown_source_file).basename.to_s,
      markdown_entry_path: "external_samples/sample-set/site/#{slug}",
      site_build_path: "external_samples/sample-set/site",
      attachment_files:
    }
  end

  def stub_external_sample_documents(documents)
    importer = instance_double(SeedSupport::ExternalSampleImporter, documents:)
    allow(SeedSupport::ExternalSampleImporter).to receive(:new).and_return(importer)
  end

  it "reports missing roots as a dry-run warning without treating it as seed success" do
    root = Rails.root.join("tmp/spec/external_samples/missing-root")
    FileUtils.rm_rf(root)

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(true)
    expect(payload.fetch(:summary)).to include(
      projects: 0,
      documents: 0,
      document_versions: 0,
      attachments: 0
    )
    expect(payload.fetch(:warnings)).to include(
      include(level: "warning", code: "root_missing", path: "tmp/spec/external_samples/missing-root")
    )
    expect(payload.fetch(:errors)).to be_empty
    expect(payload.fetch(:note)).to include("dry-run only")
    expect(payload.fetch(:note)).to include("db:seed")
    expect(payload.fetch(:note)).to include("DocumentFile writes are not executed")
  ensure
    FileUtils.rm_rf(root)
  end

  it "reports non-directory roots as a machine-readable error before importer work" do
    root = Rails.root.join("tmp/spec/external_samples/not-a-directory")
    FileUtils.mkdir_p(root.dirname)
    File.write(root, "not a directory")

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:candidates)).to be_empty
    expect(payload.fetch(:warnings)).to be_empty
    expect(payload.fetch(:errors)).to contain_exactly(
      include(level: "error", code: "root_not_directory", path: "tmp/spec/external_samples/not-a-directory")
    )
    expect(payload.fetch(:note)).to include("standard showcase regeneration")
    expect(payload.fetch(:note)).to include("CSV seed")
  ensure
    FileUtils.rm_f(root)
  end

  it "reports markdown candidates that resolve outside their source directory" do
    root, source_dir = prepare_sample_root("path-escape")
    outside_file = root.join("outside-source.md")
    escaped_link = source_dir.join("escaped.md")
    File.write(outside_file, "# Outside\n")
    File.symlink(outside_file, escaped_link)
    stub_external_sample_documents([
      document_candidate(source_dir:, markdown_source_file: escaped_link)
    ])

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:errors)).to include(
      include(level: "error", code: "markdown_outside_source_dir", path: "tmp/spec/external_samples/path-escape/sample-set/site/escaped.md")
    )
    expect(payload.fetch(:note)).to include("dry-run only")
    expect(payload.fetch(:note)).to include("DocumentVersion")
  ensure
    FileUtils.rm_rf(root)
  end

  it "reports duplicate document candidates by project, slug, and version" do
    root, source_dir = prepare_sample_root("duplicate-candidates")
    first_markdown = source_dir.join("first.md")
    second_markdown = source_dir.join("second.md")
    File.write(first_markdown, "# First\n")
    File.write(second_markdown, "# Second\n")
    stub_external_sample_documents([
      document_candidate(source_dir:, markdown_source_file: first_markdown, title: "First"),
      document_candidate(source_dir:, markdown_source_file: second_markdown, title: "Second")
    ])

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:summary)).to include(
      projects: 1,
      documents: 1,
      document_versions: 2,
      attachments: 0
    )
    expect(payload.fetch(:errors)).to contain_exactly(
      include(
        level: "error",
        code: "duplicate_document_candidate",
        message: include("EXT_SAMPLE_SET_SITE / sample / current"),
        path: include("tmp/spec/external_samples/duplicate-candidates/sample-set/site/first.md")
      )
    )
    expect(payload.fetch(:errors).first.fetch(:path)).to include("tmp/spec/external_samples/duplicate-candidates/sample-set/site/second.md")
  ensure
    FileUtils.rm_rf(root)
  end

  it "keeps missing candidate and large attachment signals machine-readable" do
    root, source_dir = prepare_sample_root("missing-and-large")
    missing_markdown = source_dir.join("missing.md")
    attachment = source_dir.join("large.bin")
    File.binwrite(attachment, "12345")
    stub_external_sample_documents([
      document_candidate(source_dir:, markdown_source_file: missing_markdown, attachment_files: [attachment])
    ])

    payload = dry_run_payload(root, max_attachment_bytes: 4)

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:summary)).to include(
      projects: 1,
      documents: 1,
      document_versions: 1,
      attachments: 1
    )
    expect(payload.fetch(:warnings)).to include(
      include(level: "warning", code: "large_attachment", path: "tmp/spec/external_samples/missing-and-large/sample-set/site/large.bin")
    )
    expect(payload.fetch(:errors)).to include(
      include(level: "error", code: "missing_candidate_file", path: "tmp/spec/external_samples/missing-and-large/sample-set/site/missing.md")
    )
    expect(payload.fetch(:note)).to include("db:seed")
    expect(payload.fetch(:note)).to include("DocumentFile writes are not executed")
  ensure
    FileUtils.rm_rf(root)
  end
end
