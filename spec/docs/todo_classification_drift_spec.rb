require "rails_helper"

RSpec.describe "ToDo classification drift" do
  REPO_ROOT = Rails.root
  TODO_PATH = REPO_ROOT.join("docs/ToDo.md")
  README_PATH = REPO_ROOT.join("docs/README.md")

  EXPECTED_CLASSIFICATIONS = [
    "具体 Issue があるもの",
    "正本 docs へ移動済みのもの",
    "人間判断待ちのもの",
    "未起票のまま残すもの"
  ].freeze

  REPRESENTATIVE_DOC_LINKS = [
    "docs/company_master_admin会社・ユーザー管理runbook.md",
    "docs/文書コメント・Q&A運用runbook.md",
    "docs/版品質チェックrunbook.md",
    "docs/specs/文書ライフサイクルと公開.md",
    "docs/internal-ui-gem-release-train-current-queue.md"
  ].freeze

  def todo
    TODO_PATH.read
  end

  def readme
    README_PATH.read
  end

  def section(title)
    todo[/^## #{Regexp.escape(title)}\n(.*?)(?=^## |\z)/m, 1] || raise("missing ToDo section: #{title}")
  end

  it "keeps README linked to ToDo as the unsettled-items entrypoint" do
    unsettled_section = readme[/^## 未確定事項\n(.*?)(?=^## |\z)/m, 1]

    expect(unsettled_section).to include("[ToDo](./ToDo.md)")
  end

  it "keeps the four ToDo reading classifications visible" do
    EXPECTED_CLASSIFICATIONS.each do |classification|
      expect(todo).to include("- #{classification}")
    end
  end

  it "keeps representative concrete issues and source-of-truth docs referenced" do
    aggregate_failures do
      expect(todo).to include("#1246")
      expect(todo).to include("#1112")
      expect(todo).to include("#3268")
      expect(todo).to include("#1300")

      REPRESENTATIVE_DOC_LINKS.each do |relative_path|
        expect(REPO_ROOT.join(relative_path)).to exist
      end
    end
  end

  it "keeps human-gated and unfiled items carrying an explicit reason" do
    aggregate_failures do
      expect(section("権限・管理画面")).to include(
        "分類: 人間判断待ち。未起票で残す理由: ワークフロー仕様の正誤判断、通知・SLA・承認権限の外部合意が必要"
      )
      expect(section("Job / 運用自動化")).to include(
        "分類: 人間判断待ち / 未起票のまま残すもの。まだ起票しない理由: 対象処理ごとの冪等性、二重実行、再試行上限が固まっていない"
      )
      expect(section("UI / UX")).to include("まだ起票しない理由: 対象画面、導線差分、受け入れ条件が画面群ごとに固まっていない")
    end
  end

  it "keeps moved and concrete issue items from duplicating future requirements" do
    aggregate_failures do
      expect(section("latest_version / バージョン管理")).to include("#1112")
      expect(section("latest_version / バージョン管理")).to include("分類: 具体 Issue あり")
      expect(section("archived / 復元")).to include("#3268")
      expect(section("archived / 復元")).to include("分類: 具体 Issue あり")
      expect(section("依存 gem の導入方針")).to include("#1300")
      expect(section("依存 gem の導入方針")).to include("分類: 正本 docs へ移動済み / 具体 Issue あり")
    end
  end
end
