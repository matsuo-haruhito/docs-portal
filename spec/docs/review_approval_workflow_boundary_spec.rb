require "rails_helper"

RSpec.describe "Review approval workflow docs boundary" do
  let(:docs_root) { Rails.root.join("docs") }

  def read_doc(path)
    docs_root.join(path).read
  end

  it "keeps the main boundary memo explicit about current support and human decisions" do
    source = read_doc("正式レビュー承認workflow境界メモ.md")

    aggregate_failures do
      expect(source).to include("current support の周辺機能と human decision 待ちの論点を読み分ける")
      expect(source).to include("新しい workflow state、通知、SLA、担当者割当、多段承認、権限変更、承認 UI はここでは定義しません")
      expect(source).to include("docs-only PR では、上記の境界をリンクや短い注意書きで揃えるだけに留めます")
      expect(source).to include("状態名、権限、通知、DB schema、controller、request spec を変更しないと完了できない場合は、このメモを根拠に停止します")
      expect(source).to include("承認 workflow の採否、状態名、通知、SLA、担当者割当、多段承認、権限変更、法務・顧客合意が必要")
    end
  end

  it "keeps ToDo wording from promoting review approval workflow into current support" do
    source = read_doc("ToDo.md")

    aggregate_failures do
      expect(source).to include("正式なレビュー・承認ワークフローを導入するかは、コメント・品質チェック・公開制御・送付運用が固まってから再評価する")
      expect(source).to include("多段承認、通知、SLA、権限変更、公開承認 state machine の実装済み workflow として扱わない")
      expect(source).to include("分類: 人間判断待ち")
      expect(source).to include("ワークフロー仕様の正誤判断、通知・SLA・承認権限の外部合意が必要")
    end
  end

  it "keeps adjacent runbooks explicit that their flows are not formal workflow automation" do
    runbooks = {
      "文書コメント・Q&A運用runbook.md" => [
        "通知、メール、SLA、回答期限、自動エスカレーションはこの runbook の対象外です",
        "通知、担当割当、SLA、ack、自動エスカレーション、状態更新を行うものではありません"
      ],
      "利用者向け確認依頼runbook.md" => [
        "新しい確認ポリシーや通知仕様はここでは定義しません",
        "正式レビュー承認 workflow の採否、承認者 chain、通知、SLA、段階承認、公開承認 policy を定義するものではありません"
      ],
      "版品質チェックrunbook.md" => [
        "新しい品質判定 policy、通知、ack、saved report、品質チェック job 化、JSON / Markdown schema の変更はここでは定義しません",
        "品質チェック結果を公開承認 gate や正式レビュー承認 workflow の状態として読む必要が出た場合は"
      ]
    }

    aggregate_failures do
      runbooks.each do |path, expected_phrases|
        source = read_doc(path)
        expected_phrases.each do |phrase|
          expect(source).to include(phrase), "expected #{path} to keep boundary phrase: #{phrase}"
        end
      end
    end
  end
end
