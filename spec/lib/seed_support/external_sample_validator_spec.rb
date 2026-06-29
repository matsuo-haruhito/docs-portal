require "rails_helper"
require "fileutils"
require "securerandom"

require Rails.root.join("db/seeds/support/external_sample_validator").to_s

RSpec.describe SeedSupport::ExternalSampleValidator do
  let(:root) { Rails.root.join("tmp", "external-sample-validator-#{SecureRandom.hex(4)}") }

  after do
    FileUtils.rm_rf(root)
  end

  def write_sample(path, content)
    full_path = root.join(path)
    FileUtils.mkdir_p(full_path.dirname)
    File.write(full_path, content)
    full_path
  end

  it "summarizes import candidates without writing seed records" do
    write_sample("sample-set/site-a/README.md", <<~MARKDOWN)
      # Site A

      ![Flow](flow.png)
    MARKDOWN
    write_sample("sample-set/site-a/flow.png", "image")
    write_sample("sample-set/site-a/提出済/README.md", "# Submitted Site A\n")

    result = nil

    expect do
      result = described_class.new(root:).call
    end.not_to change(Project, :count)

    payload = result.to_h

    expect(result).to be_valid
    expect(payload.fetch(:summary)).to include(
      projects: 1,
      documents: 1,
      document_versions: 2
    )
    expect(payload.fetch(:summary).fetch(:attachments)).to be >= 2
    expect(payload.fetch(:candidates).map { _1.fetch(:version_label) }).to contain_exactly("current", "提出済")
    expect(payload.fetch(:note)).to include("dry-run only")
  end

  it "warns about empty sample roots and site directories without markdown" do
    FileUtils.mkdir_p(root.join("empty-set", "site-without-markdown"))
    write_sample("empty-set/site-without-markdown/notes.txt", "not markdown")

    payload = described_class.new(root:).call.to_h

    expect(payload.fetch(:valid)).to be(true)
    expect(payload.fetch(:warnings)).to include(
      include(code: "site_without_markdown"),
      include(code: "no_document_candidates")
    )
    expect(payload.fetch(:summary)).to include(projects: 0, documents: 0, document_versions: 0)
  end

  it "warns when attachments exceed the configured dry-run threshold" do
    write_sample("large-set/site-a/README.md", <<~MARKDOWN)
      # Large Site

      ![Large](large.bin)
    MARKDOWN
    write_sample("large-set/site-a/large.bin", "0123456789")

    payload = described_class.new(root:, max_attachment_bytes: 5).call.to_h

    expect(payload.fetch(:warnings)).to include(
      include(code: "large_attachment", path: a_string_including("large.bin"))
    )
  end

  it "detects symlinked candidates that escape the source directory" do
    skip "symlink is not supported on this platform" unless File.respond_to?(:symlink)

    outside = Rails.root.join("tmp", "external-sample-outside-#{SecureRandom.hex(4)}.md")
    File.write(outside, "# Escaped\n")
    FileUtils.mkdir_p(root.join("escape-set", "site-a"))
    File.symlink(outside, root.join("escape-set", "site-a", "README.md"))

    payload = described_class.new(root:).call.to_h

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:errors)).to include(include(code: "markdown_outside_source_dir"))
  ensure
    FileUtils.rm_f(outside) if defined?(outside)
  end
end
