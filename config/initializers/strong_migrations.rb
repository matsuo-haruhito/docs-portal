# frozen_string_literal: true

# StrongMigrations — 危険な DDL を事前検知
# ロック長期化やデータ消失を起こすマイグレーションを開発時にブロックする。

StrongMigrations.target_postgresql_version = "18"

# 本番で安全に実行できない操作をブロック
StrongMigrations.auto_analyze = true

# start_after: この migration version 以前は既存として扱い、チェック対象外にする。
# 既存のマイグレーションを後から壊さないための設定。
# 最初のリリース前は最新 migration のタイムスタンプを設定する。
# StrongMigrations.start_after = 20260101000000
