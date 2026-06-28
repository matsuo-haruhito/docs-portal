# TreeView x RTP tree-table bridge decision

この decision record は、#2825 の first slice として TreeView x Rails Table Preferences bridge を docs-portal の current main に採用するかを整理するためのものです。

## 結論

現時点では、docs-portal に TreeView x RTP を同じ tree-table / resource-table surface として canary 化する自然な代表画面は採用しません。

TreeView は sidebar 文書ツリー / 文書詳細 tree / persisted state の smoke で維持し、RTP は admin list table preference smoke で維持します。両者を無理に 1 画面へ統合すると、host app が持つ query、authorization、route、business label、row action、pagination / loading strategy を upstream gem responsibility として扱ってしまうリスクが高いためです。

## 確認した current surface

### TreeView side

- `app/views/documents/_tree.html.erb`
  - sidebar 文書ツリーの render state、current document cue、表示中 badge、`aria-current`、tree query、window controls を扱う。
  - tree query は左ツリー内の表示絞り込みであり、RTP の table preference / column metadata とは別の状態として読ませている。
- `app/views/projects/_document_detail_tree.html.erb`
  - 文書詳細側の tree table と expand / collapse toolbar を扱う。
  - row content、route、document state、version label は docs-portal 側の business rendering であり、RTP column preference の対象としては扱っていない。
- `spec/requests/document_tree_regressions_spec.rb`
  - sidebar tree、detail tree、persisted state、window offset、tree query、current cue の regression を固定している。

### RTP side

- `app/views/admin/document_sets/index.html.slim`
  - `table_key = :admin_document_sets` と stable column key を持つ admin list surface。
  - filter / CSV / table preference editor は文書セット一覧の table state として閉じている。
- `spec/requests/admin_document_sets_index_spec.rb`
  - editor と stable column key、代表 row action を確認している。
- `spec/requests/admin_document_sets_spec.rb`
  - form state、filter、mounted engine save などの admin list / form integration を確認している。

## 採用しない理由

- TreeView の current surfaces は document hierarchy の current cue、expand/collapse、persisted state が中心で、RTP の column metadata / preference editor を同じ画面に載せる自然な user workflow がまだない。
- `admin/document_sets` は RTP / RFK の代表 surface として有効だが、TreeView-style row hierarchy を必要とする画面ではない。
- TreeView の row rendering に RTP column preference を重ねると、host app の document query、authorization、route、business label、row action、pagination / loading strategy の責務が upstream gem 側へ見えやすくなる。
- #2740 は RTP x RFK canary として別に進められており、この issue で代替または拡張しない。
- #858 の pinned ref train、#607 の screen-by-screen adoption、Gemfile pin 更新とは混ぜない。

## 維持する smoke

- TreeView smoke
  - `spec/requests/document_tree_regressions_spec.rb`
  - sidebar tree / detail tree / persisted state / current cue / tree query / window offset
- RTP smoke
  - `spec/requests/admin_document_sets_index_spec.rb`
  - `spec/requests/admin_document_sets_spec.rb`
  - admin document sets editor / stable column key / filter / preset / mounted engine save

## 次に採用を再検討する条件

TreeView x RTP bridge は、次のような current main の自然な画面が出てから再検討します。

- 文書階層を table rows として表示し、同時に column visibility / width / filter preference を user-facing state として保存する必要がある。
- tree row の expand/collapse と table preference editor が同じ workflow で使われる。
- host app 側の query、authorization、route、business label、row action、pagination / loading strategy を upstream gem responsibility として書かずに、docs-portal 側 evidence として切り分けられる。
- representative smoke と rollback note の置き場所が、TreeView smoke と RTP smoke の既存 evidence と矛盾しない。

## 非目標

- `tree_view-rails` または `rails_table_preferences` の API 変更
- docs-portal の Gemfile pin 更新
- 全 admin list の tree-table 化
- table preference / tree rendering / authorization / pagination の再設計
- RTP x RFK canary #2740 の代替

## 関連

- #2825
- #2740
- #607
- #858
- `docs/internal-ui-gem責務境界matrix.md`
- `docs/internal-ui-gem-adoption-evidence-map.md`
- `docs/関連gem連携調査runbook.md`
