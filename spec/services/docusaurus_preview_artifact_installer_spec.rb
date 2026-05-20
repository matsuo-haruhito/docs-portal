require "rails_helper"
require "rubygems/package"
require "stringio"
require "tempfile"
require "zlib"

RSpec.describe DocusaurusPreviewArtifactInstaller do
  let(:document) { create(:document, title: "Guide", slug: "guide") }
  let(:version) do
    create(:document_version, document: document, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
      record.save!
    end
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  it "installs a safe Docusaurus build artifact and updates site metadata" do
    archive = build_archive("docs/guide/index.html" => "<main>Guide</main>")

    described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!

    expect(version.reload.markdown_entry_path).to eq("docs/guide.md")
    expect(version.site_build_path).to eq("docs/guide")
    expect(version.site_root_absolute_path.join("docs/guide/index.html").read).to include("Guide")
  ensure
    archive&.close!
  end

  it "installs a flat html Docusaurus build artifact" do
    archive = build_archive("docs/guide.html" => "<main>Flat Guide</main>")

    described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!

    expect(version.reload.markdown_entry_path).to eq("docs/guide.md")
    expect(version.site_build_path).to eq("docs/guide")
    expect(version.site_root_absolute_path.join("docs/guide.html").read).to include("Flat Guide")
  ensure
    archive&.close!
  end

  it "installs a root index Docusaurus build artifact" do
    version.assign_source_path_metadata!(source_path: "index.md", snapshot_kind: "received_markdown")
    version.save!
    archive = build_archive("index.html" => "<main>Root</main>")

    described_class.new(version: version, archive_path: archive.path, site_path: "index").install!

    expect(version.reload.markdown_entry_path).to eq("index.md")
    expect(version.site_build_path).to eq("index")
    expect(version.site_root_absolute_path.join("index.html").read).to include("Root")
  ensure
    archive&.close!
  end

  it "rejects artifacts that escape the destination" do
    archive = build_archive("../escape.txt" => "escape", "docs/guide/index.html" => "ok")

    expect do
      described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!
    end.to raise_error(ApplicationError::BadRequest, /invalid/)
  ensure
    archive&.close!
  end

  it "rejects absolute artifact paths" do
    archive = build_archive("/escape.txt" => "escape", "docs/guide/index.html" => "ok")

    expect do
      described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!
    end.to raise_error(ApplicationError::BadRequest, /invalid/)
  ensure
    archive&.close!
  end

  it "rejects invalid returned site paths" do
    archive = build_archive("docs/guide/index.html" => "ok")

    expect do
      described_class.new(version: version, archive_path: archive.path, site_path: "../guide").install!
    end.to raise_error(ApplicationError::BadRequest, /path is invalid/)
  ensure
    archive&.close!
  end

  it "rejects artifacts without the expected entry html" do
    archive = build_archive("docs/other/index.html" => "other")

    expect do
      described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!
    end.to raise_error(ApplicationError::BadRequest, /missing entry path/)
  ensure
    archive&.close!
  end

  it "keeps the existing site when a new artifact is invalid" do
    existing = version.site_root_absolute_path.join("docs/guide/index.html")
    FileUtils.mkdir_p(existing.dirname)
    existing.write("existing")
    version.update!(markdown_entry_path: "docs/guide.md", site_build_path: "docs/guide")
    archive = build_archive("docs/other/index.html" => "other")

    expect do
      described_class.new(version: version, archive_path: archive.path, site_path: "docs/guide").install!
    end.to raise_error(ApplicationError::BadRequest)

    expect(existing.read).to eq("existing")
    expect(version.reload.site_build_path).to eq("docs/guide")
  ensure
    archive&.close!
  end

  private

  def build_archive(entries)
    tempfile = Tempfile.new(["artifact", ".tar.gz"])
    tempfile.binmode

    tar_buffer = StringIO.new.binmode
    Gem::Package::TarWriter.new(tar_buffer) do |tar|
      entries.each do |path, content|
        tar.add_file(path, 0o644) do |entry|
          entry.write(content)
        end
      end
    end

    Zlib::GzipWriter.open(tempfile.path) do |gzip|
      gzip.write(tar_buffer.string)
    end

    tempfile.rewind
    tempfile
  end
end
