/**
 * generate_screen_docs.ts
 *
 * docs/screenshots/ にある画面キャプチャから、画面仕様の
 * 操作説明書 (Markdown) を自動生成するスクリプト。
 *
 * Usage:
 *   npx tsx script/generate_screen_docs.ts
 *
 * Output:
 *   docs/screen_guide.md (default, SCREEN_GUIDE_OUTPUT で変更可)
 */

import fs from "node:fs"
import path from "node:path"

const SCREENSHOTS_DIR = path.resolve(process.env.SCREENSHOT_DIR || "docs/screenshots")
const OUTPUT_FILE = path.resolve(process.env.SCREEN_GUIDE_OUTPUT || "docs/screen_guide.md")

// --- 型定義 ---

interface GroupDef {
  key: string
  label: string
  story: string
  screenOperations?: Record<string, string[]>
}

interface ScreenEntry {
  file: string
  action: string
  caption: string
}

interface ScreenGroup extends GroupDef {
  screens: ScreenEntry[]
}

// アクション名 → 日本語キャプション
const ACTION_LABELS: Record<string, string> = {
  index: "一覧画面",
  new: "新規作成画面",
  edit: "編集画面",
  show: "詳細画面",
  dashboard: "ダッシュボード",
  assignments: "権限一覧",
  overview: "文書別概要",
  favorite: "お気に入り",
  read_later: "後で読む",
  recent: "最近見た文書",
}

// --- 画面グループ定義 ---

const ADMIN_GROUP_DEFS: GroupDef[] = [
  {
    key: "admin_dashboard", label: "管理ダッシュボード",
    story: "管理者がシステム全体の状況を俯瞰するトップ画面",
    screenOperations: { dashboard: ["文書数・案件数・ユーザー数の確認", "最近の同期状態やジョブ状態の確認"] },
  },
  {
    key: "admin_diagnostics", label: "運用・診断",
    story: "管理者が設定・保存ファイル・運用ジョブの詳細な診断情報を確認する",
    screenOperations: {
      index: ["設定診断・文書ファイル健全性・Storage内訳の確認", "継続失敗候補とrunbook導線の確認"],
    },
  },
  {
    key: "admin_companies", label: "会社マスタ",
    story: "管理者が会社（テナント）を登録・管理する",
    screenOperations: {
      index: ["会社の検索・フィルタ・一覧確認", "列設定のカスタマイズ"],
      edit: ["会社情報（ドメイン・会社名・有効/無効）の編集"],
    },
  },
  {
    key: "admin_users", label: "ユーザーマスタ",
    story: "管理者がユーザーアカウントを登録・管理する",
    screenOperations: {
      index: ["ユーザーの検索・フィルタ（キーワード・状態）", "列設定のカスタマイズ"],
      edit: ["ユーザー情報（名前・メール・種別・会社・パスワード）の編集"],
    },
  },
  {
    key: "admin_projects", label: "案件マスタ",
    story: "管理者が案件を登録・管理する",
    screenOperations: {
      index: ["案件の検索・フィルタ（キーワード・会社・状態）", "列設定のカスタマイズ"],
      edit: ["案件情報（コード・名称・会社・状態）の編集"],
    },
  },
  {
    key: "admin_project_memberships", label: "案件所属",
    story: "管理者がユーザーの案件所属を管理する",
    screenOperations: {
      index: ["案件所属の一覧確認・フィルタ"],
      edit: ["所属設定（ユーザー・案件・ロール）の編集"],
    },
  },
  {
    key: "admin_documents", label: "文書マスタ",
    story: "管理者が文書を登録・管理し、版管理やアーカイブを行う",
    screenOperations: {
      index: [
        "文書の検索・フィルタ（キーワード・カテゴリ・種別・公開範囲・正本区分・状態）",
        "列設定のカスタマイズ",
        "一括編集候補の選択",
        "保管期限・廃棄候補のライフサイクル管理",
      ],
      edit: ["文書情報（案件・タイトル・slug・カテゴリ・種別・公開範囲・正本区分）の編集"],
    },
  },
  {
    key: "admin_document_sets", label: "文書セット",
    story: "管理者が文書のグループ（セット）を作成し、配布対象を管理する",
    screenOperations: {
      index: ["文書セットの検索・フィルタ（名称・種別・公開範囲）", "CSV出力", "列設定のカスタマイズ"],
    },
  },
  {
    key: "admin_document_catalogs", label: "文書カタログ",
    story: "管理者が公開側に表示する文書カタログを管理する",
    screenOperations: {
      index: ["カタログの一覧確認・管理"],
    },
  },
  {
    key: "admin_document_permissions", label: "文書権限",
    story: "管理者が文書ごとのアクセス権限（会社・ユーザー単位）を付与する",
    screenOperations: {
      assignments: ["権限の検索・フィルタ（案件・文書名・アクセスレベル・付与先種別）", "CSV出力"],
      overview: ["文書別の権限付与状況と付与先の要約確認", "案件・文書名による絞り込み"],
      edit: ["権限設定（文書・付与先・アクセスレベル）の編集"],
    },
  },
  {
    key: "admin_bulk_edit_dry_runs", label: "文書一括編集",
    story: "管理者が複数文書のメタデータを一括変更する（dry-run → 実行）",
    screenOperations: {
      new: ["一括編集のdry-run作成（対象文書・変更内容の指定）"],
    },
  },
  {
    key: "admin_git_import_sources", label: "Git連携設定",
    story: "管理者がGitリポジトリからの文書取り込み設定を管理する",
    screenOperations: {
      index: ["Git連携設定の検索・フィルタ（案件・状態）", "手動同期の実行"],
      edit: ["連携設定（リポジトリ・ブランチ・取込元パス・認証）の編集"],
    },
  },
  {
    key: "admin_git_import_runs", label: "Git同期履歴",
    story: "管理者がGit同期の実行結果を確認する",
    screenOperations: {
      index: ["同期履歴の一覧確認・フィルタ（案件・ステータス）"],
    },
  },
  {
    key: "admin_external_folder_sync_sources", label: "外部フォルダ同期設定",
    story: "管理者がGoogle Drive / SharePointからの文書取り込み設定を管理する",
    screenOperations: {
      index: [
        "同期設定の一覧確認・フィルタ（プロバイダ・状態・警告/エラー）",
        "OAuth接続の管理",
        "同期プレビュー・強制適用の実行",
      ],
    },
  },
  {
    key: "admin_microsoft_graph_connections", label: "Microsoft Graph接続",
    story: "管理者がMicrosoft Graph（SharePoint/OneDrive）接続を管理する",
    screenOperations: {
      index: ["接続設定の一覧・新規登録・編集"],
    },
  },
  {
    key: "admin_webhook_endpoints", label: "Webhook設定",
    story: "管理者が外部通知用のWebhookエンドポイントを管理する",
    screenOperations: {
      index: [
        "Webhook設定の一覧・フィルタ（名称・イベント・状態）",
        "最近の送信履歴の確認",
        "失敗Webhookの再送",
      ],
    },
  },
  {
    key: "admin_webhook_deliveries", label: "Webhook送信履歴検索",
    story: "管理者がWebhook送信の詳細履歴を検索・確認する",
    screenOperations: {
      index: ["送信履歴の検索・フィルタ（設定・イベント・ステータス・日時）"],
    },
  },
  {
    key: "admin_zip_imports", label: "ZIPインポート",
    story: "管理者がZIPファイルから文書を一括取り込みする",
    screenOperations: {
      new: ["ZIPファイルのアップロード（案件・版ラベル・ステータス指定）", "dry-runの作成"],
    },
  },
  {
    key: "admin_file_upload_dry_runs", label: "単体ファイルアップロード",
    story: "管理者が個別ファイルのアップロード結果を確認する",
    screenOperations: {
      index: ["アップロードdry-runの一覧確認"],
    },
  },
  {
    key: "admin_generated_file_events", label: "生成ファイルイベント",
    story: "管理者がDocusaurus build等のファイル生成イベントを確認する",
    screenOperations: {
      index: ["生成イベントの一覧確認・フィルタ"],
    },
  },
  {
    key: "admin_generated_file_runs", label: "生成ファイル実行",
    story: "管理者がファイル生成ジョブの実行結果を確認・再実行する",
    screenOperations: {
      index: ["生成ジョブの一覧・フィルタ（ステータス・案件）", "失敗ジョブの一括再実行"],
      show: ["ジョブ詳細の確認（入出力・エラー）", "個別再実行"],
    },
  },
  {
    key: "admin_recurring_job_schedules", label: "定期ジョブ",
    story: "管理者が定期実行ジョブのスケジュールを管理する",
    screenOperations: {
      index: ["定期ジョブの一覧確認・同期"],
      show: ["ジョブ詳細・実行履歴の確認", "即時実行の要求"],
    },
  },
  {
    key: "admin_consent_terms", label: "同意文面",
    story: "管理者が利用者に表示する同意文面を管理する",
    screenOperations: {
      index: ["同意文面の一覧確認・フィルタ"],
    },
  },
  {
    key: "admin_project_consent_settings", label: "案件別同意設定",
    story: "管理者が案件ごとの同意要求設定を管理する",
    screenOperations: {
      index: ["案件別同意設定の一覧確認"],
    },
  },
  {
    key: "admin_access_logs", label: "アクセスログ",
    story: "管理者がユーザーの操作履歴を確認する（監査用）",
    screenOperations: {
      index: ["アクセスログの検索・フィルタ（ユーザー・操作種別・対象・日時）"],
    },
  },
  {
    key: "admin_access_requests", label: "アクセス申請（管理）",
    story: "管理者がユーザーからのアクセス申請を承認・却下する",
    screenOperations: {
      index: ["申請の一覧確認・フィルタ（ステータス・申請者）"],
    },
  },
  {
    key: "admin_document_usage_reports", label: "文書利用レポート",
    story: "管理者が文書の利用状況を集計・確認する",
    screenOperations: {
      index: ["文書利用状況の集計レポート表示"],
    },
  },
  {
    key: "admin_read_confirmations", label: "既読確認",
    story: "管理者が文書の既読確認状況を管理する",
    screenOperations: {
      index: ["既読確認の一覧・フィルタ"],
    },
  },
]

const PUBLIC_GROUP_DEFS: GroupDef[] = [
  {
    key: "dashboard", label: "ダッシュボード",
    story: "ログインユーザーが自分に関連する文書・案件の状況を確認するトップ画面",
    screenOperations: {
      dashboard: ["アクセス可能な案件と文書の一覧確認", "最近閲覧した文書へのクイックアクセス"],
    },
  },
  {
    key: "projects", label: "案件一覧・詳細",
    story: "ユーザーがアクセス可能な案件と所属文書を閲覧する",
    screenOperations: {
      index: ["案件の一覧確認・検索"],
      show: ["案件配下の文書ツリー表示", "文書の閲覧・ダウンロードへの遷移"],
    },
  },
  {
    key: "accessible_documents", label: "閲覧可能文書一覧",
    story: "ユーザーが権限のある文書を案件横断で検索する",
    screenOperations: {
      index: ["キーワード・案件・タグによる文書検索", "追加条件によるカテゴリ・ファイル種・公開範囲等の絞り込み"],
    },
  },
  {
    key: "documents", label: "文書閲覧",
    story: "ユーザーが文書の内容を閲覧し、添付ファイルをダウンロードする",
    screenOperations: {
      index: ["アクセス可能な文書の横断検索"],
      show: ["文書のHTMLプレビュー表示", "版の切り替え", "添付ファイルの一覧・ダウンロード", "コメント・Q&Aの確認"],
    },
  },
  {
    key: "document_approval_requests", label: "確認依頼",
    story: "ユーザーが文書の確認依頼を送信・管理する",
    screenOperations: {
      index: ["確認依頼の一覧・フィルタ（ステータス・依頼者・承認者）"],
    },
  },
  {
    key: "document_delivery_logs", label: "送付履歴",
    story: "ユーザーが文書の外部送付履歴を確認する",
    screenOperations: {
      index: ["送付履歴の一覧・フィルタ（ステータス・方式）"],
    },
  },
  {
    key: "document_bookmarks", label: "ショートカット",
    story: "ユーザーがお気に入り・後で読む文書と最近見た文書を確認する",
    screenOperations: {
      favorite: ["お気に入り文書の検索・確認", "お気に入りの解除"],
      read_later: ["後で読む文書の検索・確認", "お気に入りへの移動・登録解除"],
      recent: ["最近見た文書の検索・確認", "文書詳細への移動"],
    },
  },
  {
    key: "access_requests", label: "アクセス申請",
    story: "ユーザーがアクセス権のない文書・案件への申請を行う",
    screenOperations: {
      index: ["申請の一覧確認（ステータス・種別）", "新規アクセス申請の作成"],
    },
  },
  {
    key: "consents", label: "同意管理",
    story: "ユーザーが同意履歴を確認し、必要な同意を行う",
    screenOperations: {
      index: ["同意履歴の確認", "有効な同意文面の確認"],
    },
  },
  {
    key: "root", label: "トップページ",
    story: "ログイン後の初期表示ページ",
    screenOperations: {
      index: ["案件一覧へのリダイレクト"],
    },
  },
]

// --- ユーティリティ関数 ---

function actionCaption(action: string, groupLabel: string): string {
  if (ACTION_LABELS[action]) return `${groupLabel} ${ACTION_LABELS[action]}`
  return `${groupLabel} — ${action.replace(/_/g, " ")}`
}

function encodeAnchor(label: string): string {
  return label.toLowerCase().replace(/[^\p{L}\p{N}\s-]/gu, "").replace(/\s+/g, "-")
}

// --- メイン処理 ---

function main(): void {
  const allFiles = fs
    .readdirSync(SCREENSHOTS_DIR)
    .filter((f) => f.endsWith(".png"))
    .sort()

  const allDefs: GroupDef[] = [...ADMIN_GROUP_DEFS, ...PUBLIC_GROUP_DEFS].sort(
    (a, b) => b.key.length - a.key.length
  )

  const claimed = new Set<string>()
  const groups: ScreenGroup[] = []

  for (const def of allDefs) {
    const screens: ScreenEntry[] = []
    for (const file of allFiles) {
      if (claimed.has(file)) continue
      const base = file.replace(/\.png$/, "")
      if (base !== def.key && !base.startsWith(def.key + "_")) continue
      const action = base === def.key ? "dashboard" : base.slice(def.key.length + 1)
      const actionName = action || "index"
      screens.push({
        file,
        action: actionName,
        caption: actionCaption(actionName, def.label),
      })
      claimed.add(file)
    }
    if (screens.length > 0) {
      groups.push({ ...def, screens })
    }
  }

  const unclaimed = allFiles.filter((f) => !claimed.has(f))

  // --- Markdown 生成 ---
  const lines: string[] = []
  lines.push("# 画面操作ガイド")
  lines.push("")
  lines.push("> このドキュメントは `npx tsx script/generate_screen_docs.ts` で自動生成されています。")
  lines.push("> スクリーンショットは `docs/screenshots/` を参照しています。")
  lines.push("")
  lines.push("---")
  lines.push("")

  // 目次
  lines.push("## 目次")
  lines.push("")

  const adminGroups = groups.filter((g) => ADMIN_GROUP_DEFS.some((d) => d.key === g.key))
  const publicGroups = groups.filter((g) => PUBLIC_GROUP_DEFS.some((d) => d.key === g.key))

  const orderByDef = (defs: { key: string }[]) => (a: ScreenGroup, b: ScreenGroup) => {
    const ai = defs.findIndex((d) => d.key === a.key)
    const bi = defs.findIndex((d) => d.key === b.key)
    return ai - bi
  }
  adminGroups.sort(orderByDef(ADMIN_GROUP_DEFS))
  publicGroups.sort(orderByDef(PUBLIC_GROUP_DEFS))

  lines.push("### 管理画面")
  lines.push("")
  for (const g of adminGroups) lines.push(`- [${g.label}](#${encodeAnchor(g.label)})`)
  lines.push("")
  lines.push("### 利用者画面")
  lines.push("")
  for (const g of publicGroups) lines.push(`- [${g.label}](#${encodeAnchor(g.label)})`)
  lines.push("")
  lines.push("---")
  lines.push("")

  // 各セクション出力
  function renderSection(title: string, sectionGroups: ScreenGroup[]): void {
    lines.push(`## ${title}`)
    lines.push("")
    for (const group of sectionGroups) renderGroup(group)
  }

  function renderGroup(group: ScreenGroup): void {
    lines.push(`### ${group.label}`)
    lines.push("")
    lines.push(`**用途:** ${group.story}`)
    lines.push("")

    for (const screen of group.screens) {
      const imgPath = `screenshots/${screen.file}`
      lines.push(`#### ${screen.caption}`)
      lines.push("")

      const ops = resolveScreenOperations(group, screen.action)
      if (ops && ops.length > 0) {
        lines.push("**この画面での操作:**")
        lines.push("")
        for (const op of ops) lines.push(`- ${op}`)
        lines.push("")
      }

      lines.push(`![${screen.caption}](${imgPath})`)
      lines.push("")
    }
  }

  function resolveScreenOperations(group: ScreenGroup, action: string): string[] | undefined {
    if (!group.screenOperations) return undefined
    if (group.screenOperations[action]) return group.screenOperations[action]
    const suffix = action.split("_").pop()
    if (suffix && group.screenOperations[suffix]) return group.screenOperations[suffix]
    return undefined
  }

  renderSection("管理画面", adminGroups)
  renderSection("利用者画面", publicGroups)

  if (unclaimed.length > 0) {
    lines.push("## その他")
    lines.push("")
    for (const file of unclaimed) {
      const imgPath = `screenshots/${file}`
      lines.push(`- ![${file}](${imgPath})`)
    }
    lines.push("")
  }

  const content = lines.join("\n") + "\n"
  fs.writeFileSync(OUTPUT_FILE, content, "utf-8")
  console.log(`Generated: ${path.relative(process.cwd(), OUTPUT_FILE)}`)
  console.log(`  ${allFiles.length} screenshots, ${groups.length} groups, ${unclaimed.length} unclaimed`)
}

main()
