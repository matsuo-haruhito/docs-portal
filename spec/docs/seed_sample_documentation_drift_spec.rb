require "rails_helper"

RSpec.describe "standard seed sample documentation drift" do
  REPO_ROOT = Rails.root
  GENERATOR_PATH = REPO_ROOT.join("db/seeds/support/seed_sample_document_generator.rb")
  SEED_DOCS_PATH = REPO_ROOT.join("docs/標準seedサンプルと確認用途.md")
  ROOT_README_PATH = REPO_ROOT.join("README.md")
  DOCS_README_PATH = REPO_ROOT.join("docs/README.md")

  EXPECTED_CURRENT_ARTIFACTS = [
    "README.md",
    "runbook.md",
    "process.mmd",
    "runbook.csv",
    "README.pdf",
    "README.xlsx",
    "sample-archive.zip"
  ].freeze

  EXPECTED_PREVIOUS_ARTIFACTS = [
    "提出済/README.md"
  ].freeze

  def generator_source
    GENERATOR_PATH.read
  end

  def seed_docs
    SEED_DOCS_PATH.read
  end

  def root_readme
    ROOT_README_PATH.read
  end

  def docs_readme
    DOCS_README_PATH.read
  end

  def generated_current_artifacts
    generator_source.scan(/current_root\.join\("([^"]+)"\)/).flatten
  end

  def generated_previous_artifacts
    previous_label = generator_source[/PREVIOUS\s*=\s*"([^"]+)"/, 1] ||
                     raise("missing previous seed sample label")

    generator_source.scan(/previous_root\.join\("([^"]+)"\)/).flatten.map do |path|
      "#{previous_label}/#{path}"
    end
  end

  it "keeps the documented showcase path aligned with generator constants" do
    aggregate_failures do
      expect(generator_source).to include('SAMPLE_SET = "seed-showcase"')
      expect(generator_source).to include('SITE = "docs-portal-demo"')
      expect(generator_source).to include('PREVIOUS = "提出済"')

      expect(seed_docs).to include("`seed-showcase/docs-portal-demo`")
      expect(seed_docs).to include("`提出済/README.md`")
    end
  end

  it "keeps representative generated artifacts documented for review smoke" do
    expected_artifacts = EXPECTED_CURRENT_ARTIFACTS + EXPECTED_PREVIOUS_ARTIFACTS

    aggregate_failures do
      expect(generated_current_artifacts).to match_array(EXPECTED_CURRENT_ARTIFACTS)
      expect(generated_previous_artifacts).to match_array(EXPECTED_PREVIOUS_ARTIFACTS)

      expected_artifacts.each do |artifact|
        expect(seed_docs).to include("`#{artifact}`")
      end
    end
  end

  it "keeps the review smoke checklist anchored to the representative viewer flows" do
    checklist = seed_docs[/^## PR review 用 smoke checklist\n(.*?)(?=^## |\z)/m, 1] ||
                raise("missing standard seed sample smoke checklist")

    aggregate_failures do
      expect(checklist).to include("viewer / preview / download")
      expect(checklist).to include("current の `README.md` と旧版 `提出済/README.md`")
      expect(checklist).to include("ZIP preview")
      expect(checklist).to include("Office preview")
    end
  end

  it "keeps README entrypoints pointing at the seed sample docs" do
    aggregate_failures do
      expect(root_readme).to include("標準 seed サンプルと確認用途")
      expect(root_readme).to include("./docs/%E6%A8%99%E6%BA%96seed%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB%E3%81%A8%E7%A2%BA%E8%AA%8D%E7%94%A8%E9%80%94.md")
      expect(docs_readme).to include("[標準 seed サンプルと確認用途](./標準seedサンプルと確認用途.md)")
    end
  end
end
