require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_builder")

RSpec.describe SeedSupport::DocusaurusBuilder do
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "Seed Doc", slug: "seed-doc") }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      site_build_path: "external_samples/sample-set/seed-doc/v1.0.0"
    )
  end
  let(:source_dir) { Rails.root.join("tmp", "seed-doc-source-#{SecureRandom.hex(4)}") }

  before do
    FileUtils.mkdir_p(source_dir.join("guide"))
    File.write(source_dir.join("README.md"), "# Hello\n")
    File.write(source_dir.join("guide", "README.md"), "# Guide\n")

    allow_any_instance_of(described_class).to receive(:run_build!) do |service, docs_src, build_output_dir|
      expect(docs_src.join(version.site_build_path, "index.md")).to exist
      expect(docs_src.join(version.site_build_path, "guide", "index.md")).to exist

      FileUtils.mkdir_p(build_output_dir.join(version.site_build_path))
      File.write(
        build_output_dir.join(version.site_build_path, "index.html"),
        <<~HTML
          <html class="docs-doc-id-#{version.site_build_path}/#{described_class.seed_doc_id_for("README.md")}">
            <body><h1>Hello</h1></body>
          </html>
        HTML
      )
      FileUtils.mkdir_p(build_output_dir.join(version.site_build_path, "guide"))
      File.write(
        build_output_dir.join(version.site_build_path, "guide", "index.html"),
        <<~HTML
          <html class="docs-doc-id-#{version.site_build_path}/guide/#{described_class.seed_doc_id_for("guide/README.md")}">
            <body><h1>Guide</h1></body>
          </html>
        HTML
      )
    end
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  it "normalizes README markdown files, copies the built site, and returns resolved routes" do
    route_map = described_class.new(
      source_dir:,
      version:,
      site_build_path: version.site_build_path
    ).build

    expect(version.site_entry_absolute_path).to exist
    expect(version.site_entry_absolute_path.read).to include("Hello")
    expect(route_map[described_class.seed_doc_id_for("README.md")]).to eq(version.site_build_path)
    expect(route_map[described_class.seed_doc_id_for("guide/README.md")]).to eq("#{version.site_build_path}/guide")
  end
end
