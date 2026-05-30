require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_builder")
require Rails.root.join("db/seeds/support/docusaurus_workspace_populator")

RSpec.describe SeedSupport::DocusaurusWorkspacePopulator do
  let(:source_dir) { Rails.root.join("tmp", "pop-src-#{SecureRandom.hex(4)}") }
  let(:docs_src) { Rails.root.join("tmp", "pop-docs-#{SecureRandom.hex(4)}") }
  let(:site_build_path) { "external_samples/sample/current" }

  before do
    FileUtils.mkdir_p(source_dir.join("guide"))
    FileUtils.mkdir_p(source_dir.join("assets"))
    FileUtils.mkdir_p(source_dir.join("日本語", "nested"))
    File.write(source_dir.join("README.md"), "# Root\n")
    File.write(source_dir.join("guide", "README.md"), "# Guide\n")
    File.write(source_dir.join("日本語", "nested", "詳細.markdown"), "# 詳細\n")
    File.write(source_dir.join("assets", "logo.png"), "image")
  end

  after do
    FileUtils.rm_rf(source_dir)
    FileUtils.rm_rf(docs_src)
  end

  it "places markdown and local assets into the docs source" do
    described_class.new(
      source_dir:,
      docs_src:,
      site_build_path:
    ).populate!

    root = docs_src.join(site_build_path)
    expect(root.join("index.md")).to exist
    expect(root.join("guide", "index.md")).to exist
    expect(root.join("日本語", "nested", "詳細.markdown")).to exist
    expect(root.join("assets", "logo.png")).to exist
  end

  it "uses stable generated ids from original seed relative paths" do
    described_class.new(
      source_dir:,
      docs_src:,
      site_build_path:
    ).populate!

    root = docs_src.join(site_build_path)

    expect(root.join("index.md").read).to include(
      "id: #{SeedSupport::DocusaurusBuilder.seed_doc_id_for(Pathname("README.md"))}"
    )
    expect(root.join("guide", "index.md").read).to include(
      "id: #{SeedSupport::DocusaurusBuilder.seed_doc_id_for(Pathname("guide/README.md"))}"
    )
    expect(root.join("日本語", "nested", "詳細.markdown").read).to include(
      "id: #{SeedSupport::DocusaurusBuilder.seed_doc_id_for(Pathname("日本語/nested/詳細.markdown"))}"
    )
  end
end
