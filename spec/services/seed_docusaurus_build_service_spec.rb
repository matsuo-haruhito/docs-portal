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
    FileUtils.mkdir_p(source_dir.join("flows"))
    File.write(source_dir.join("README.md"), "# Hello\n")
    File.write(source_dir.join("guide", "README.md"), "# Guide\n")
    File.write(source_dir.join("flows", "shipping.mmd"), "flowchart TD\n  A --> B\n")

    allow(SeedSupport::DocusaurusBuildRunner).to receive(:new) do |source_dir:, version:, docs_src:, build_output_dir:, static_dir:|
      expect(docs_src.join(version.site_build_path, "index.md")).to exist
      expect(docs_src.join(version.site_build_path, "guide", "index.md")).to exist
      expect(static_dir.basename.to_s).to eq("static")

      diagram_wrapper = docs_src.join(version.site_build_path, "flows", "shipping.md")
      expect(diagram_wrapper).to exist
      expect(diagram_wrapper.read).to include("id: #{described_class.seed_doc_id_for("flows/shipping.mmd")}")
      expect(diagram_wrapper.read).to include("```mermaid")
      expect(diagram_wrapper.read).to include("flowchart TD")

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
      FileUtils.mkdir_p(build_output_dir.join(version.site_build_path, "flows", "shipping"))
      File.write(
        build_output_dir.join(version.site_build_path, "flows", "shipping", "index.html"),
        <<~HTML
          <html class="docs-doc-id-#{version.site_build_path}/flows/#{described_class.seed_doc_id_for("flows/shipping.mmd")}">
            <body><h1>shipping</h1></body>
          </html>
        HTML
      )

      instance_double(
        SeedSupport::DocusaurusBuildRunner,
        run!: begin
          FileUtils.mkdir_p(version.site_root_absolute_path)
          FileUtils.rm_rf(version.site_root_absolute_path.children)
          FileUtils.cp_r(build_output_dir.children, version.site_root_absolute_path)
        end
      )
    end
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  it "detects standalone diagram files as renderable document files" do
    expect(described_class.renderable_document_file?("flow.puml")).to be(true)
    expect(described_class.renderable_document_file?("flow.plantuml")).to be(true)
    expect(described_class.renderable_document_file?("flow.d2")).to be(true)
    expect(described_class.renderable_document_file?("flow.mmd")).to be(true)
    expect(described_class.renderable_document_file?("flow.mermaid")).to be(true)
    expect(described_class.renderable_document_file?("image.png")).to be(false)
  end

  it "normalizes README markdown files and standalone diagram files, copies the built site, and returns resolved routes" do
    route_map = described_class.new(
      source_dir:,
      version:,
      site_build_path: version.site_build_path
    ).build

    expect(version.site_entry_absolute_path).to exist
    expect(version.site_entry_absolute_path.read).to include("Hello")
    expect(route_map[described_class.seed_doc_id_for("README.md")]).to eq(version.site_build_path)
    expect(route_map[described_class.seed_doc_id_for("guide/README.md")]).to eq("#{version.site_build_path}/guide")
    expect(route_map[described_class.seed_doc_id_for("flows/shipping.mmd")]).to eq("#{version.site_build_path}/flows/shipping")
  end
end
