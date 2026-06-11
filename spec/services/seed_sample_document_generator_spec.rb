require "rails_helper"
require "fileutils"
require "tmpdir"

require Rails.root.join("db/seeds/support/seed_sample_document_generator").to_s

RSpec.describe SeedSupport::SeedSampleDocumentGenerator do
  around do |example|
    Dir.mktmpdir("seed-sample-document-generator") do |tmp_dir|
      @tmp_root = Pathname(tmp_dir)
      example.run
    end
  end

  let(:root) { @tmp_root }
  let(:site_root) { root.join("seed-showcase", "docs-portal-demo") }
  let(:current_files) do
    %w[
      README.md
      runbook.md
      process.mmd
      runbook.csv
      README.pdf
      README.xlsx
    ]
  end

  subject(:generator) { described_class.new(root:) }

  it "generates the current and previous showcase files under the injected root" do
    sentinel = site_root.join("stale.txt")
    FileUtils.mkdir_p(site_root)
    sentinel.write("old file")

    generator.run

    aggregate_failures "generated file layout" do
      expect(sentinel.exist?).to be(false)
      current_files.each do |relative_path|
        expect(site_root.join(relative_path).file?).to be(true), "expected #{relative_path} to be generated"
      end
      expect(site_root.join("提出済", "README.md").file?).to be(true)
    end

    readme = site_root.join("README.md").read
    aggregate_failures "README content and attachment links" do
      expect(readme).to include("# サンプル文書ポータル標準セット")
      expect(readme).to include("代表導線の smoke 用サンプル")
      expect(readme).to include("unsafe path / nested archive / huge ZIP / bulk download")
      expect(readme).to include("Kroki 実 service の疎通確認")
      expect(readme).to include("[サンプルPDF](./README.pdf)")
      expect(readme).to include("[サンプルExcel](./README.xlsx)")
      expect(readme).to include("[運用CSV](./runbook.csv)")
      expect(readme).to include("```mermaid")
      expect(readme).to include("@startuml")
    end

    aggregate_failures "representative text files" do
      expect(site_root.join("runbook.md").read).to include("運用確認 Runbook")
      expect(site_root.join("process.mmd").read).to include("seed[db:seed]")
      expect(site_root.join("runbook.csv").read).to include("step,actor,expected")
      expect(site_root.join("提出済", "README.md").read).to include("複数版確認用の旧版")
    end
  end

  it "recreates only the standard showcase site and leaves sibling external samples intact" do
    stale_showcase_file = site_root.join("stale.txt")
    ai_usecase_file = root.join("ai-usecases", "customer-support", "README.md")
    optional_sample_file = root.join("optional-samples", "partner-demo", "README.md")

    [stale_showcase_file, ai_usecase_file, optional_sample_file].each do |path|
      FileUtils.mkdir_p(path.dirname)
      path.write("keep this file")
    end

    generator.run

    aggregate_failures "external sample deletion boundary" do
      expect(stale_showcase_file.exist?).to be(false)
      expect(ai_usecase_file.exist?).to be(true)
      expect(ai_usecase_file.read).to eq("keep this file")
      expect(optional_sample_file.exist?).to be(true)
      expect(optional_sample_file.read).to eq("keep this file")
    end
  end

  it "generates non-empty PDF, XLSX, and CSV artifacts with lightweight format markers" do
    generator.run

    csv = site_root.join("runbook.csv").read
    pdf = site_root.join("README.pdf").binread
    xlsx = site_root.join("README.xlsx").binread

    aggregate_failures "generated artifact markers" do
      expect(csv.lines.size).to be >= 4
      expect(pdf.bytesize).to be > 100
      expect(pdf).to start_with("%PDF-1.4")
      expect(pdf).to include("%%EOF")
      expect(xlsx.bytesize).to be > 100
      expect(xlsx).to start_with("PK\x03\x04".b)
      expect(xlsx).to include("[Content_Types].xml")
      expect(xlsx).to include("xl/workbook.xml")
      expect(xlsx).to include("xl/worksheets/sheet1.xml")
    end
  end
end