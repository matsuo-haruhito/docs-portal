require "rails_helper"
require "fileutils"
require "securerandom"

require Rails.root.join("db/seeds/support/seed_sample_document_generator")

RSpec.describe SeedSupport::SeedSampleDocumentGenerator do
  let(:root) { Rails.root.join("tmp", "seed-sample-document-generator", SecureRandom.hex(8)) }
  let(:showcase_root) { root.join(described_class::SAMPLE_SET, described_class::SITE) }

  after do
    FileUtils.rm_rf(root)
  end

  it "keeps the standard showcase artifact inventory aligned with docs" do
    described_class.new(root:).run

    expected_paths = [
      "README.md",
      "README.pdf",
      "README.xlsx",
      "process.mmd",
      "runbook.csv",
      "runbook.md",
      "sample-archive.zip",
      "提出済/README.md"
    ]

    generated_paths = Dir.glob(showcase_root.join("**", "*"))
      .select { |path| File.file?(path) }
      .map { |path| Pathname(path).relative_path_from(showcase_root).to_s }
      .sort

    expect(generated_paths).to eq(expected_paths)

    docs = Rails.root.join("docs", "標準seedサンプルと確認用途.md").read
    expected_paths.each do |relative_path|
      expect(docs).to include("`#{relative_path}`")
    end

    readme = Rails.root.join("README.md").read
    expect(readme).to include("標準 showcase は seed 時に `seed-showcase/docs-portal-demo` として再生成される")
    expect(readme).to include("標準 seed サンプルと確認用途")
  end
end
