# 文書ショートカット運用runbook

このrunbookは、`文書ショートカット`画面をcurrent UIに沿って見返すための運用メモです。

新しいショートカット種別や並び替えルールはここでは定義しません。`お気に入り`、`後で読む`、`最近見た文書`をどう読み分けるか、選択中のタブで検索・ページ移動・行操作をしたあとにどこへ戻るかを整理します。

## 先に見るもの

1. dashboardからの入口と個人導線の役割差は[ダッシュボードと文書ショートカット・確認依頼の使い分け](../../specs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md)
2. 権限や利用者種別の前提は[アプリケーション仕様](../../アプリケーション仕様.md)と[基本モデルと権限](../../specs/基本モデルと権限.md)
3. 文書詳細から`お気に入りに追加` / `後で読むに追加`する導線は文書詳細画面を正本に確認する

## 画面の役割

`GET /document_bookmarks`は、current userの個人用ショートカットと閲覧履歴をタブ単位で見直す画面です。

- `お気に入り`: 継続的に参照する文書
- `後で読む`: 今すぐではないが、あとで確認する文書
- `最近見た文書`: bookmarkではなく閲覧履歴から作る再訪先

画面は3タブで構成し、1回の応答では選択中のタブに対応するpanelだけを描画します。非選択タブの一覧、empty state、filterは同じ応答に描画しません。

`view`の値と初期表示:

| タブ | `view` | 表示内容 |
| --- | --- | --- |
| お気に入り | `favorite` | favorite bookmark |
| 後で読む | `read_later` | read_later bookmark |
| 最近見た文書 | `recent` | `RecentDocumentsQuery`の結果 |

`view`を省略した場合、または上記以外の値を指定した場合は`favorite`へ正規化します。タブは`tablist` / `tab`、選択中の内容は対応する`tabpanel`として扱います。

## タブと条件の保持

タブ切替、検索、条件クリア、ページ移動、`解除`、`お気に入りへ移す`では`view`を持ち回り、操作後も同じタブへ戻ります。Refererがない行操作でも、fallback URLに`view`と許可済みの検索・page paramを含めます。

タブを切り替えるときは、現在の次の条件を保持したまま移動先の`view`だけを変更します。

- `project_code`
- `bookmark_q`
- `recent_q`
- `favorite_page`
- `read_later_page`

これらは別タブへ戻ったときの文脈を復元するための値です。非選択タブの一覧を同時に描画するためのものではありません。

## `お気に入り`の見方

`view=favorite`では、お気に入りだけを表示します。

- 保存済みショートカット用の案件filterと検索欄を表示する
- 文書名、案件名、`よく開く文書`badge、`解除`を表示する
- filter後のfavoriteを追加順で最大20件ずつ表示する
- 複数pageがある場合だけ`前へ` / `次へ`を表示する
- pager、条件解除、`解除`は`view=favorite`を維持する

0件時は、条件の有無を見分けます。条件なしならまだお気に入りがない状態、条件ありなら現在の案件・検索語に一致しない状態です。条件ありの場合だけ保存済み条件を解除する導線を表示します。

## `後で読む`の見方

`view=read_later`では、後で読む文書だけを表示します。

- 保存済みショートカット用の案件filterと検索欄を表示する
- 文書名、案件名、`あとで確認`badge、`お気に入りへ移す`、`解除`を表示する
- filter後のread_laterを追加順で最大20件ずつ表示する
- 複数pageがある場合だけ`前へ` / `次へ`を表示する
- pager、条件解除、`お気に入りへ移す`、`解除`は`view=read_later`を維持する

`お気に入りへ移す`は、同じ文書のfavorite bookmarkを`find_or_create_by!`で用意し、元のread_later bookmarkを削除します。すでにfavoriteがある場合は再利用します。

0件時は、お気に入りと同様に条件なしの初期状態と、filterによる0件を分けて読みます。

## `最近見た文書`の見方

`view=recent`では、`RecentDocumentsQuery`が返すreadableな最大20件だけを表示します。

- recent専用の検索欄を表示する
- 文書名、案件名、`最近見た文書`badgeを表示する
- `recent_q`で文書名、案件名、案件コードを絞り込む
- bookmarkではないため`解除`や`お気に入りへ移す`は表示しない
- 検索と条件クリアは`view=recent`を維持する

検索対象は表示中の最大20件であり、閲覧履歴全体の横断検索ではありません。検索で0件になった場合は`最近見た条件をクリア`で`recent_q`だけを外せます。履歴自体が0件の場合は、`文書を開くと、最近見た文書としてここに表示されます。`という初期状態として読みます。

recent最大20件内に目的の文書がない場合は、案件一覧または案件横断の文書一覧から探し直します。

## 保存済みショートカットの絞り込み

`view=favorite`または`view=read_later`では、同じ保存済みfilterを使います。

- `案件`: readableな保存済みbookmarkに紐づく案件から選ぶ
- `保存済みショートカットを検索`: 文書名、案件名、案件コードを部分一致で探す

`bookmark_q`はstrip後、`DocumentBookmarksController::BOOKMARK_QUERY_MAX_LENGTH`の最大100文字に丸めます。指定した案件コードが候補にない場合は、選択中のbookmark種別で0件として扱います。

`保存済み条件を解除`は`project_code`と`bookmark_q`、保存済みpage paramを外しますが、`view`は維持します。recent検索はrecentタブで独立して扱います。

## 追加・移動・解除

文書詳細の`管理・補助操作`には、次の導線があります。

- `お気に入りに追加`
- `後で読むに追加`
- `文書ショートカット一覧`

追加は元の文書詳細へ戻ります。一覧上の`解除`と`お気に入りへ移す`は、通常はRefererの一覧へ戻り、Refererがない場合も許可済みのnavigation paramから同じタブのfallback URLを組み立てます。

画面下部の`案件一覧へ戻る`は`GET /projects`への固定リンクです。

## 日常確認ポイント

- 選択中のタブに対応するpanelだけが表示されているか
- タブ切替後に意図した`view`が選択されているか
- favorite / read_laterで案件・検索語・pageが保持されているか
- recent検索と条件クリアが`view=recent`を維持しているか
- 行操作後、Refererの有無にかかわらず操作元のタブへ戻れるか
- 0件が未登録・履歴なしなのか、filterによる0件なのかを区別できるか
- readableでなくなった文書がbookmarkや履歴に残っていても表示されていないか

## 変更時の注意

- 3タブを装飾だけに戻し、3sectionを同時描画しない
- `view`は`favorite`、`read_later`、`recent`だけを許可し、不正値をそのままDOMやqueryへ渡さない
- 非選択タブの一覧やempty stateを同じ応答の検証対象にしない
- `お気に入り`と`後で読む`は別種別として併存できるが、`お気に入りへ移す`はread_later側だけの操作とする
- `最近見た文書`をbookmarkと同じ削除・並び替え対象として扱わない
- page link、filter、条件クリア、行操作から`view`を落とさない
- readableでなくなった文書は表示対象外とし、このrunbookで復旧手順扱いにしない

## 迷ったときの切り分け

- 継続して読む文書を残したい: `お気に入り`
- 後で確認する文書を一時的に積みたい: `後で読む`
- さっき見ていた文書へ戻りたい: `最近見た文書`
- 保存済みを案件や検索語で絞りたい: favorite / read_laterタブのfilter
- recent最大20件内を探したい: recentタブの検索
- read_laterをfavorite扱いへ変えたい: read_laterタブの`お気に入りへ移す`
- bookmark整理後に案件単位の導線へ戻りたい: `案件一覧へ戻る`

## 関連画面

- `app/views/dashboard/show.html.erb`
- `app/controllers/document_bookmarks_controller.rb`
- `app/views/document_bookmarks/index.html.erb`
- `app/views/documents/_detail_sections.html.slim`
- `config/routes.rb`
- `spec/requests/document_bookmarks_spec.rb`
- `spec/requests/document_bookmarks_pagination_spec.rb`
- `spec/requests/document_bookmarks_filter_cues_spec.rb`
- `spec/requests/document_bookmarks_recent_empty_state_spec.rb`
- `spec/requests/document_bookmarks_recent_search_project_code_spec.rb`
