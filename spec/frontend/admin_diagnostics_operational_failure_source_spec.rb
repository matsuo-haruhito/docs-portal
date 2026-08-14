require "rails_helper"

RSpec.describe "Admin diagnostics operational failure source" do
  let(:view_source) { Rails.root.join("app/views/admin/diagnostics/index.html.slim").read }

  it "keeps saved history and consecutive failure candidates visually separated" do
    aggregate_failures do
      expect(view_source).to include("section#failures.card.diagnostic-section")
      expect(view_source).to include("h2 運用失敗")
      expect(view_source).to include("h4 保存済み履歴")
      expect(view_source).to include("保存済み履歴の件数です。継続失敗候補や通知状態とは別に確認します。")
      expect(view_source).to include("h4 継続失敗候補")
      expect(view_source).to include("同じidentityの最新runが連続して失敗している候補です。")
      expect(view_source).to include("通知・確認済み・自動復旧・正常保証の状態ではありません。")
      expect(view_source).to include('GuidanceDisclosureComponent.new(title: "集計条件を確認")')
    end
  end

  it "keeps stale history cue scoped away from severity and notification state" do
    aggregate_failures do
      expect(view_source).to include("strong 古い失敗のみ")
      expect(view_source).to include("7日より古い履歴だけが残っています")
      expect(view_source).to include("対象履歴の最終更新")
      expect(view_source).to include("発生時刻や通知時刻ではありません")
    end
  end
end
