require "rails_helper"
require "tmpdir"

require Rails.root.join("db/seeds/support/seed_sample_document_generator").to_s

RSpec.describe "standard seed showcase documentation" do
  REPO_ROOT = Rails.root
  DOC_PATH = REPO_ROOT.join("docs/標準seedサンプルと確認用途.md")
  README_PATH = REPO_ROOT.join("README.md")
  SAMPLE_SET = SeedSupport::SeedSampleDocumentGenerator::SAMPLE_SET
  SITE = SeedSupport::SeedSampleDocumentGenerator::SITE

  def docs_source
    DOC_PATH.read
  end

  def readme_source
    README_PATH.read
  end

  def generated_showcase_paths
    Dir.mktmpdir("seed-showcase") do |dir|
      root = Pathname(dir)
      SeedSupport::SeedSampleDocumentGenerator.new(root: root).run
      site_root = root.join(SAMPLE_SET, SITE)

      Dir.glob(site_root.join("**/*")).filter_map do |path|
        next unless File.file?(path)

        Pathname(path).relative_path_from(site_root).to_s
      end.sort
    end
  end

  def documented_showcase_paths
    section = docs_source[/^## 標準 showcase の生成内容\n(.*?)(?=^## |\z)/m, 1]
    raise "#{DOC_PATH.relative_path_from(REPO_ROOT)} is missing the standard showcase section" unless section

    section.scan(/^\| `([^`]+)` \|/).flatten.sort
  end

  it "keeps the documented standard showcase file list aligned with the seed generator" do
    expect(documented_showcase_paths).to eq(generated_showcase_paths), <<~MESSAGE
      Standard seed showcase docs drifted from SeedSampleDocumentGenerator.
      Compare docs/標準seedサンプルと確認用途.md with db/seeds/support/seed_sample_document_generator.rb.
      The guard covers only seed-showcase/docs-portal-demo paths, including 提出済/README.md.
      ai-usecases and arbitrary external_samples are intentionally outside this list.
    MESSAGE
  end

  it "keeps the standard showcase distinct from optional and purpose-specific samples" do
    aggregate_failures do
      expect(docs_source).to include("標準 showcase サンプルは `db/seeds/support/seed_sample_document_generator.rb` が毎回再生成します")
      expect(docs_source).to include("`ai-usecases` や任意サンプルは、この generator とは別")
      expect(docs_source).to include("任意サンプルは、標準 showcase とは別の `<sample-set>` 配下に置きます")
      expect(readme_source).to include("標準 showcase は seed 時に `seed-showcase/docs-portal-demo` として再生成されるため、直接編集せず")
      expect(readme_source).to include("`ai-usecases` は手順書系コンテンツの初期サンプルです")
      expect(readme_source).to include("標準 showcase、`ai-usecases`、任意 `external_samples` の役割分担")
    end
  end

  it "keeps optional sample cleanup and review smoke boundaries explicit" do
    aggregate_failures do
      expect(docs_source).to include("この script は root directory を用意するだけで、サンプルの検証、cleanup、retention 判断は行いません")
      expect(docs_source).to include("production data の cleanup 方針はこの手順では決まりません")
      expect(docs_source).to include("browser visual regression、full system spec、seed generator の変更を必須化するものではありません")
    end
  end
end
