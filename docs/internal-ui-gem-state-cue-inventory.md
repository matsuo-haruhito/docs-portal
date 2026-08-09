# internal UI gem state cue inventory

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を並べて使うときに、状態表示 cue の意味と責務境界を読み合わせるための inventory です。

---

## 読み方

- `表示目的`: 利用者が何を読み取れるようにする cue か。
- `代表画面`: docs-portal 側で確認しやすい画面。
- `host app override`: docs-portal 側で文言・密度・周辺説明を調整してよい範囲。
- gem-owned な class、event、helper option の新設は upstream 側の issue で扱う。

---

## TreeView state cue

| state cue | 表示目的 | 代表画面 | host app override |
|-----------|---------|---------|------------------|
| current row | いま本文側で開いている文書を tree 内で追跡する | sidebar 文書ツリー | current 判定は host app route / selected document が正本。`current-node` + `aria-current="page"` + `表示中` badge |
| collapsed / expanded | 階層を閉じているのか、子要素がないのかを誤読しない | sidebar 文書ツリー | 空 branch の説明や fallback 文言は host app 側で補える |
| loading | Turbo refresh や非同期更新中であることを伝える | 文書ツリー refresh | 待機文言や skeleton の有無は host app 判断 |
| error | tree 更新失敗を通常の空状態と分ける | 文書ツリー refresh failure | 復旧案内文、再試行ボタンの有無は host app の画面 issue |

## Rails Table Preferences state cue

| state cue | 表示目的 | 代表画面 | host app override |
|-----------|---------|---------|------------------|
| active filter | 一覧が絞り込み済みであることを 0 件時も読み返せる | 文書セット、監査ログ | filter label / business wording は host app 正本 |
| sort | 並び順が既定でないことを列見出しで読み取れる | rtp 採用済み一覧 | sort label と default order は host app 側で固定 |
| preset scope | 表示設定 preset がどの一覧に効いているかを誤読しない | `admin/document_sets` | table_key、preset 名は host app 側で screen ごとに固定 |
| editor open | 表示設定を編集中で通常閲覧と状態が違うことを示す | `admin/document_sets` | editor 周辺の説明、閉じる導線は host app 側 |
| fixed column | 操作列が横スクロール時も見失われない | company / user 一覧 | どの列を固定するかは画面 issue で決める |

---

## 文書ツリー state と詳細一覧 table/filter state の連携境界

### 代表画面

案件詳細の文書ツリー（左ペイン）+ 文書一覧（右ペイン / 詳細側）。

### 連携候補 vs 非連携 対応表

| TreeView 側 state | 詳細一覧側 state | 連携する？ | 根拠 |
|-------------------|-----------------|-----------|------|
| current row（現在開いている文書） | active filter（一覧の検索条件） | **非連携** | tree で文書を選ぶ操作と、一覧の filter 条件は別の意図。tree は「今見ている文書」、filter は「一覧の絞り込み条件」 |
| current row | column width / 表示設定 | **非連携** | 表示列の幅や表示ON/OFF は一覧全体の preference。文書選択で変わるべきものではない |
| current row | preset scope | **非連携** | preset は「この一覧でよく使う表示条件」の保存。文書切替で自動的に preset を変えない |
| expanded / collapsed（ツリー開閉） | active filter | **非連携** | ツリーのフォルダ開閉は navigation 補助。一覧の検索条件と独立 |
| expanded / collapsed | sort | **非連携** | ツリー開閉で一覧のソート順を変える理由がない |
| tree search（ツリー内検索） | active filter | **非連携** | ツリー内検索は左ペインだけを絞り込む。`spec/frontend/document_tree_current_selection_source_spec.rb` で「検索は左のツリーだけを絞り込みます。」と固定済み |
| current row | viewer table preference context | **非連携** | Markdown preview table の context は文書版・site path・table index から決まり、ツリー選択で preference を自動変更しない。current fallback に具体的な不足が出た場合だけ別 issue にする |

### 判断基準

- TreeView の state は「navigation 補助」— 今どこにいるか、階層のどこを開いているか
- RTP の state は「一覧の表示 preference」— どの列を見せるか、どう並べるか、どう絞るか
- 両者は **独立した責務** であり、一方の変更が他方を自動的に書き換える連携は current support として導入しない
- viewer 内 table の preference context は文書版・site path・table index を正本にし、current document のツリー選択から自動変更しない

### 連携しない理由の補足

1. ユーザーの意図が異なる: ツリーで文書 A を開くのは「A を読みたい」、一覧で filter するのは「条件に合う文書を探したい」
2. 操作頻度が異なる: ツリーは頻繁にクリックされるが、filter/preset の変更は意図的な設定操作
3. 自動連携は混乱を招く: ツリーで別文書をクリックするたびに一覧の filter が変わると、ユーザーが「自分で設定した条件」を失う

---

## user preference / localStorage / server-side preference の current support

| 保存先 | 対象 | 方式 |
|--------|------|------|
| server-side (DB) | ツリー展開状態 | `tree_view_state_for(instance_key)` — User model の `TreeViewStateOwner` concern |
| server-side (DB) | 一覧表示設定 | `rails_table_preferences` mounted engine — table_key 単位で preference 保存 |
| server-side (session) | 検索条件 | rparam によるセッション記憶 |
| localStorage | なし（current support） | Markdown preview table の列幅 fallback のみ (`preview_table_resizer_controller.js`) |

---

## 将来変更との関係

- Markdown table full RTP 化は active queue に置かず、current fallback で具体的な不足が再現した場合に新しい issue にする
- screen-by-screen adoption は対象画面と state cue を 1 画面単位で確認する
- 文書詳細本文側 state cue は current behavior として維持する

---

## この文書で決めないこと

- `tree_view` / `rails_table_preferences` / `rails_fields_kit` の upstream API 変更
- internal UI gem pinned ref 更新
- Markdown table の full RTP integration
- 全 viewer / admin 一覧への state 連携一括展開
- visual regression 基盤導入
