require "rails_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

require Rails.root.join("db/seeds/support/external_sample_validator").to_s

RSpec.describe "external sample dry-run validation" do
  EXTERNAL_SAMPLE_DRY_RUN_REPO_ROOT = Rails.root
  EXTERNAL_SAMPLE_DRY_RUN_BIN_PATH = EXTERNAL_SAMPLE_DRY_RUN_REPO_ROOT.join("bin/validate_external_samples")
  EXTERNAL_SAMPLE_DRY_RUN_TOP_LEVEL_KEYS = %i[root valid summary candidates warnings errors note].freeze
  EXTERNAL_SAMPLE_DRY_RUN_SUMMARY_KEYS = %i[projects document_versions documents attachments].freeze
  EXTERNAL_SAMPLE_DRY_RUN_CANDIDATE_KEYS = %i[
    project_code
    project_name
    title
    slug
    version_label
    source_dir
    markdown_path
    markdown_entry_path
    site_build_path
    attachments
  ].freeze
  EXTERNAL_SAMPLE_DRY_RUN_FINDING_KEYS = %i[level code message path].freeze

  def with_external_sample_root
    Dir.mktmpdir("external-samples") do |dir|
      yield Pathname(dir)
    end
  end

  def write_external_sample(root, sample_set: "sample-set", site: "site-one", markdown_path: "docs/README.md")
    site_root = root.join(sample_set, site)
    markdown_file = site_root.join(markdown_path)
    FileUtils.mkdir_p(markdown_file.dirname)
    markdown_file.write("# External sample guide\n\nSeed dry-run contract fixture.\n")

    attachment = site_root.join("assets/attachment.txt")
    FileUtils.mkdir_p(attachment.dirname)
    attachment.write("attachment body\n")

    site_root
  end

  def validator_result(root, **options)
    SeedSupport::ExternalSampleValidator.new(root:, **options).call.to_h
  end

  def finding_codes(payload, key)
    payload.fetch(key).map { |finding| finding.fetch(:code) }
  end

  def run_cli(*args)
    Open3.capture3(
      { "RAILS_ENV" => "test" },
      RbConfig.ruby,
      EXTERNAL_SAMPLE_DRY_RUN_BIN_PATH.to_s,
      *args
    )
  end

  it "keeps the JSON dry-run payload shape and note boundary stable" do
    with_external_sample_root do |root|
      write_external_sample(root)

      payload = validator_result(root)
      candidate = payload.fetch(:candidates).sole

      aggregate_failures do
        expect(payload.keys).to eq(EXTERNAL_SAMPLE_DRY_RUN_TOP_LEVEL_KEYS)
        expect(payload.fetch(:valid)).to be(true)
        expect(payload.fetch(:summary).keys).to eq(EXTERNAL_SAMPLE_DRY_RUN_SUMMARY_KEYS)
        expect(candidate.keys).to include(*EXTERNAL_SAMPLE_DRY_RUN_CANDIDATE_KEYS)
        expect(candidate.fetch(:project_code)).to be_present
        expect(candidate.fetch(:project_name)).to eq("sample-set / site-one")
        expect(candidate.fetch(:markdown_path)).to eq("docs/README.md")
        expect(candidate.fetch(:attachments)).to be >= 1
        expect(payload.fetch(:warnings)).to eq([])
        expect(payload.fetch(:errors)).to eq([])
        expect(payload.fetch(:note)).to include("dry-run only")
        expect(payload.fetch(:note)).to include("db:seed")
        expect(payload.fetch(:note)).to include("DocumentFile writes are not executed")
      end
    end
  end

  it "keeps representative warnings readable without making the dry-run invalid" do
    with_external_sample_root do |root|
      missing_root = root.join("missing")
      missing_payload = validator_result(missing_root)
      expect(missing_payload.fetch(:valid)).to be(true)
      expect(finding_codes(missing_payload, :warnings)).to include("root_missing")
      expect(missing_payload.fetch(:errors)).to eq([])

      empty_root = root.join("empty")
      FileUtils.mkdir_p(empty_root)
      empty_payload = validator_result(empty_root)
      expect(empty_payload.fetch(:valid)).to be(true)
      expect(finding_codes(empty_payload, :warnings)).to include("no_sample_sets", "no_document_candidates")

      site_without_markdown = root.join("plain-set", "plain-site")
      FileUtils.mkdir_p(site_without_markdown)
      site_without_markdown.join("notes.txt").write("not markdown\n")
      plain_payload = validator_result(root.join("plain-set"))
      expect(plain_payload.fetch(:valid)).to be(true)
      expect(finding_codes(plain_payload, :warnings)).to include("site_without_markdown", "no_document_candidates")
    end
  end

  it "keeps representative validation errors distinct from warnings" do
    with_external_sample_root do |root|
      file_root = root.join("not-a-directory")
      file_root.write("not a directory\n")

      payload = validator_result(file_root)
      error = payload.fetch(:errors).sole

      aggregate_failures do
        expect(payload.fetch(:valid)).to be(false)
        expect(payload.fetch(:warnings)).to eq([])
        expect(error.keys).to eq(EXTERNAL_SAMPLE_DRY_RUN_FINDING_KEYS)
        expect(error).to include(
          level: "error",
          code: "root_not_directory",
          message: "external sample root must be a directory"
        )
      end
    end
  end

  it "keeps large attachments as warnings while preserving the candidate" do
    with_external_sample_root do |root|
      site_root = write_external_sample(root)
      site_root.join("assets/attachment.txt").write("large dry-run warning fixture\n")

      payload = validator_result(root, max_attachment_bytes: 1)

      aggregate_failures do
        expect(payload.fetch(:valid)).to be(true)
        expect(payload.fetch(:candidates).size).to eq(1)
        expect(finding_codes(payload, :warnings)).to include("large_attachment")
        expect(payload.fetch(:errors)).to eq([])
      end
    end
  end

  it "keeps CLI JSON output and exit statuses stable" do
    with_external_sample_root do |root|
      write_external_sample(root)

      stdout, stderr, status = run_cli("--root=#{root}", "--format=json")
      payload = JSON.parse(stdout)

      aggregate_failures "valid JSON dry-run" do
        expect(status.exitstatus).to eq(0)
        expect(stderr).to eq("")
        expect(payload.keys).to eq(EXTERNAL_SAMPLE_DRY_RUN_TOP_LEVEL_KEYS.map(&:to_s))
        expect(payload.fetch("valid")).to be(true)
        expect(payload.fetch("summary").keys).to eq(EXTERNAL_SAMPLE_DRY_RUN_SUMMARY_KEYS.map(&:to_s))
      end

      file_root = root.join("not-a-directory")
      file_root.write("not a directory\n")
      stdout, stderr, status = run_cli("--root=#{file_root}", "--format=json")
      invalid_payload = JSON.parse(stdout)

      aggregate_failures "invalid JSON dry-run" do
        expect(status.exitstatus).to eq(1)
        expect(stderr).to eq("")
        expect(invalid_payload.fetch("valid")).to be(false)
        expect(invalid_payload.fetch("errors").map { |finding| finding.fetch("code") }).to include("root_not_directory")
      end

      stdout, stderr, status = run_cli("--root=#{root}", "--format=yaml")

      aggregate_failures "unsupported format" do
        expect(status.exitstatus).to eq(2)
        expect(stdout).to eq("")
        expect(stderr).to include("Unsupported format: yaml")
        expect(stderr).to include("Usage: bin/validate_external_samples")
      end
    end
  end
end
