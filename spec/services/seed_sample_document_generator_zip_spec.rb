require "rails_helper"
require "tmpdir"

require Rails.root.join("db/seeds/support/seed_sample_document_generator").to_s

RSpec.describe SeedSupport::SeedSampleDocumentGenerator do
  around do |example|
    Dir.mktmpdir("seed-sample-document-generator-zip") do |tmp_dir|
      @tmp_root = Pathname(tmp_dir)
      example.run
    end
  end

  let(:root) { @tmp_root }
  let(:site_root) { root.join("seed-showcase", "docs-portal-demo") }

  subject(:generator) { described_class.new(root:) }

  it "generates a deterministic sample archive and links it from the current README" do
    generator.run

    archive_path = site_root.join("sample-archive.zip")
    archive = archive_path.binread
    readme = site_root.join("README.md").read

    aggregate_failures "sample archive contract" do
      expect(archive_path.file?).to be(true)
      expect(archive.bytesize).to be > 100
      expect(archive).to start_with("PK\x03\x04".b)
      expect(archive).to include("archive-readme.md")
      expect(archive).to include("data/preview.csv")
      expect(archive).to include("notes/nested-entry.txt")
      expect(archive).to include("ZIP preview sample")
      expect(archive).to include("sample,zip-preview")
      expect(readme).to include("[サンプルZIP](./sample-archive.zip)")
    end

    generator.run

    expect(site_root.join("sample-archive.zip").binread).to eq(archive)
  end
end
