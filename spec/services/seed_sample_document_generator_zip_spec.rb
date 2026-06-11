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
    archive_entries = local_zip_entries(archive)
    readme = site_root.join("README.md").read

    aggregate_failures "sample archive contract" do
      expect(archive_path.file?).to be(true)
      expect(archive.bytesize).to be > 100
      expect(archive).to start_with("PK\x03\x04".b)
      expect(archive_entries.keys).to eq([
        "archive-readme.md",
        "data/preview.csv",
        "notes/nested-entry.txt"
      ])
      expect(archive_entries["archive-readme.md"]).to include("ZIP preview sample")
      expect(archive_entries["data/preview.csv"]).to include("sample,zip-preview")
      expect(archive_entries["notes/nested-entry.txt"]).to include("nested directory entry")
      expect(readme).to include("[サンプルZIP](./sample-archive.zip)")
    end

    generator.run

    expect(site_root.join("sample-archive.zip").binread).to eq(archive)
  end

  def local_zip_entries(archive)
    entries = {}
    offset = 0

    loop do
      signature = archive.byteslice(offset, 4)
      break unless signature == "PK\x03\x04".b

      header = archive.byteslice(offset, 30).unpack("VvvvvvVVVvv")
      compressed_size = header.fetch(7)
      filename_size = header.fetch(9)
      extra_size = header.fetch(10)
      filename_offset = offset + 30
      data_offset = filename_offset + filename_size + extra_size
      filename = archive.byteslice(filename_offset, filename_size)
      data = archive.byteslice(data_offset, compressed_size)

      entries[filename] = data
      offset = data_offset + compressed_size
    end

    entries
  end
end
