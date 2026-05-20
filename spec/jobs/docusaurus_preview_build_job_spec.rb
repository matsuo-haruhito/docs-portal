require "rails_helper"
require "rubygems/package"
require "tempfile"
require "zlib"

RSpec.describe DocusaurusPreviewBuildJob, type: :job do
  let(:document) { create(:document, title: "Guide", slug: "guide") }
  let(:version) do
    create(:document_version, document: document, source_commit_hash: "manual-upload").tap do |record|
      record.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
      record.save!
    end
  end

  after do
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/docusaurus-preview-build-job"))
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.persisted?
  end

  it "sends the version archive to the renderer and installs the returned artifact" do
    create_source_file!("docs/guide.md", "# Guide")
    artifact = build_artifact("docs/guide/index.html" => "<main>Guide</main>")
    client = instance_double(DocusaurusRendererClient)

    allow(DocusaurusRendererClient).to receive(:new).and_return(client)
    allow(client).to receive(:build).and_return(
      DocusaurusRendererClient::Result.new(archive_file: artifact, site_path: "docs/guide")
    )

    described_class.perform_now(version.id)

    expect(client).to have_received(:build).with(
      archive_file: an_instance_of(Tempfile),
      entry_path: "docs/guide.md"
    )
    expect(version.reload.markdown_entry_path).to eq("docs/guide.md")
    expect(version.site_build_path).to eq("docs/guide")
    expect(version.site_root_absolute_path.join("docs/guide/index.html").read).to include("Guide")
  end

  it "skips non-markdown versions" do
    version.assign_source_path_metadata!(source_path: "docs/guide.pdf", snapshot_kind: "pdf_generated")
    version.save!

    expect(DocusaurusRendererClient).not_to receive(:new)

    described_class.perform_now(version.id)
  end

  private

  def create_source_file!(file_name, content)
    storage_key = "spec/docusaurus-preview-build-job/#{SecureRandom.hex(8)}.md"
    absolute_path = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    absolute_path.write(content)

    version.document_files.create!(
      file_name: file_name,
      content_type: "text/markdown",
      storage_key: storage_key,
      file_size: absolute_path.size,
      sort_order: 0,
      scan_status: :scan_pending
    )
  end

  def build_artifact(entries)
    tempfile = Tempfile.new(["docusaurus-job-artifact", ".tar.gz"])
    tempfile.binmode

    Zlib::GzipWriter.open(tempfile.path) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        entries.each do |path, content|
          tar.add_file(path, 0o644) { |entry| entry.write(content) }
        end
      end
    end

    tempfile.rewind
    tempfile
  end
end
