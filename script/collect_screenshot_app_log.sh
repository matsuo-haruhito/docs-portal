#!/usr/bin/env bash
# スクリーンショット撮影中のアプリログから 500 エラーを検出する。
# 引数: アプリログファイルのパス
set -u

LOG_FILE="${1:-log/development.log}"

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  echo "No app log file found: $LOG_FILE"
  exit 0
fi

error_count=$(grep -c "Completed 500" "$LOG_FILE" 2>/dev/null || echo "0")

if [ "$error_count" -gt 0 ]; then
  echo "ERROR: ${error_count} pages returned 500 Internal Server Error during screenshots."
  echo ""
  echo "Affected requests:"
  # 各 500 エラーの直前の Started 行を抽出する
  awk '/Started (GET|POST|PATCH|PUT|DELETE)/{req=$0} /Completed 500/{print "  " req}' "$LOG_FILE" | sort -u
  echo ""
  echo "Error summary:"
  # エラーの種類を抽出（Completed 500 の数行後にエラークラスが出力される）
  grep -A5 "Completed 500" "$LOG_FILE" | grep -v "^--$\|Completed 500\|^$\|Caused by:" | grep -E "Error \(|Error$" | sed 's/ (.*//' | sort -u | sed 's/^/  /'
  exit 1
else
  echo "No 500 errors during screenshots."
  exit 0
fi
