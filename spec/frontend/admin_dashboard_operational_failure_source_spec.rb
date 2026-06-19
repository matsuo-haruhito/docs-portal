require "rails_helper"

RSpec.describe "Admin dashboard operational failure source" do
  let(:view_source) { Rails.root.join("app/views/admin/dashboard/index.html.slim").read }

  it "keeps saved history and consecutive failure candidates visually separated" do
    aggregate_failures do
      expect(view_source).to include("h2 運用失敗入口")
      expect(view_source).to include("h4 保存済み履歴")
      expect(view_source).to include("保存済み履歴の件数です。継続失敗候補や通知状態とは別に確認します。")
      expect(view_source).to include("h4 継続失敗候補")
      expect(view_source).to include("保存済み履歴とは別に、同じ identity の最新 run が連続 failed かだけを確認します")
      expect(view_source).to include("通知・ack・自動復旧の状態ではありません")
      expect(view_source).to include("保存済み failed 件数とは別の read-only 調査入口です")
      expect(view_source).to include("候補 0 件は正常保証ではありません")
    end
  end

  it "keeps stale history cue scoped away from severity and notification state" do
    aggregate_failures do
      expect(view_source).to include("strong 古い失敗のみ")
      expect(view_source).to include("7日より古い対象履歴だけが残っています")
      expect(view_source).to include("緊急度、通知状態、ack 状態を示す表示ではありません")
      expect(view_source).to include("対象履歴の最終更新")
      expect(view_source).to include("発生時刻や alert 発火時刻ではありません")
    end
  end
end
