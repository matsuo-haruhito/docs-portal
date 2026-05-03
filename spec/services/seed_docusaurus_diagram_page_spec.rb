require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_diagram_page")

RSpec.describe SeedSupport::DocusaurusDiagramPage do
  let(:source_dir) { Rails.root.join("tmp", "diagram-page-#{SecureRandom.hex(4)}") }
  let(:source_file) { source_dir.join("flows", "shipping.mmd") }

  before do
    FileUtils.mkdir_p(source_file.dirname)
    File.write(source_file, "flowchart TD\n  A --> B\n")
  end

  after do
    FileUtils.rm_rf(source_dir)
  end

  it "renders a markdown page for a standalone diagram file" do
    markdown = described_class.new(
      source: source_file,
      relative: "flows/shipping.mmd",
      language: "mermaid",
      generated_id: "seed-diagram"
    ).markdown

    fence = "`" * 3
    expect(markdown).to include("id: seed-diagram")
    expect(markdown).to include("# shipping")
    expect(markdown).to include("#{fence}mermaid")
    expect(markdown).to include("flowchart TD")
  end
end
