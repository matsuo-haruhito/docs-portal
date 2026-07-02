#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

BOUNDARY_CHECKS = [
  {
    path: "docs/正式レビュー承認workflow境界メモ.md",
    expected: [
      "current support",
      "human decision 待ち",
      "ここでは定義しません",
      "通知、SLA、担当者割当、多段承認、権限変更",
      "`回答済み`",
      "`解決`",
      "`OK済み`",
      "`送付済み`",
      "正式 workflow と混同しない境界"
    ]
  },
  {
    path: "docs/文書コメント・Q&A運用runbook.md",
    expected: [
      "未実装の workflow を前提にしないでください",
      "通知、担当割当、SLA、ack、自動エスカレーション、状態更新を行うものではありません",
      "問い合わせが存在しない保証、通知済み、回答済み、SLA 達成、ack 済みを意味しません",
      "どちらの操作も Q&A thread の状態ラベルを変えるための current UI です"
    ]
  },
  {
    path: "docs/版品質チェックrunbook.md",
    expected: [
      "read-only evidence",
      "公開承認 gate や正式レビュー承認 workflow の状態として読む必要が出た場合",
      "`pass` も承認済みや公開許可済みを意味せず",
      "品質チェックを公開承認 gate、通知、ack、差し戻し workflow として使いたい"
    ]
  },
  {
    path: "docs/利用者向け確認依頼runbook.md",
    expected: [
      "正式レビュー承認 workflow の採否、承認者 chain、通知、SLA、段階承認、公開承認 policy を定義するものではありません",
      "`OK済み` は依頼単位の確認が済んだことを示す status です",
      "顧客承認済み、法務承認済み、公開承認済み、正式 workflow 完了済みを自動的には意味しません",
      "正式レビュー承認 workflow、公開承認、送付承認へ広げたい"
    ]
  },
  {
    path: "docs/外部送付履歴運用runbook.md",
    expected: [
      "送付状態の変更、通知 channel への送信、alert rule の発火、自動 retry を実行するものではありません",
      "`送付済み` または `送付失敗` になった履歴では、detail に状態更新 action は出ず",
      "候補 0 件や検索結果 0 件を、mail 全体正常、外部監視 green、通知済み、ack 済みと誤読していないか",
      "承認 workflow はここへ足しません"
    ]
  },
  {
    path: "docs/ToDo.md",
    expected: [
      "人間判断待ちのもの",
      "多段承認、通知、SLA、権限変更、公開承認 state machine の実装済み workflow として扱わない",
      "分類: 人間判断待ち",
      "状態名・通知・SLA・段階承認は current support として先取りしない"
    ]
  }
].freeze

errors = []

BOUNDARY_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = REPO_ROOT.join(relative_path)

  unless path.file?
    errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected formal-review boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Formal review workflow boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Formal review workflow boundary docs guard passed."
