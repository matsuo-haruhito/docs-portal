# internal UI gem release train current wave 2026-06-12

この文書は `#2831` の decision record です。`#858` / `#2555` / `#2576` の release train を進める前に、2026-06-12 JST 時点の RFK / TreeView / RTP 候補を同じ粒度で読み分けます。

この文書では `Gemfile` / `Gemfile.lock` を変更しません。open PR、mergeable PR、merged PR、stale / replacement PR、人間判断待ちを同じ readiness として扱わないことを目的にします。

## Current Wave Summary

| 順序 | gem | current wave に含める候補 | 次 wave / merge 後再確認 | docs-portal representative smoke | rollback note の置き場所 |
| --- | --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit` | table metadata reader family と package-root helper familyを先に見る。候補は `rails_fields_kit#1480`, `#1472`, `#1476`, `#1481` | `#1471` の `rfk_range_field` は docs-portal 直接 canary が薄いため、次 wave または helper adoption issue へ分ける | `admin/document_sets` form の selected value / invalid rerender。table metadata reader を採用候補に含める場合は RFK table metadata docs と docs-portal table canaryを分けて記録する | bump PR body または対象 child issue comment の 1 箇所。RFK evidence と docs-portal smoke を分ける |
| 2 | `tree_view` | docs reader journey は merged evidence として読み、event detail / row data boundary は open PR として merge 後再確認に残す。候補は merged `tree_view-rails#1872`, `#1873`、open `#1835`, `#1847`, `#1874` | open public event detail / row status data PR は current support として固定しない。merge 後に sidebar tree / detail tree smoke へ接続する | sidebar tree、detail tree、persisted state、必要なら event detail を使う representative surface。event detail は upstream merge 後に確認する | `docs/internal-gem-release-train-smoke.md` の tree_view update log 形式か PR body 1 箇所 |
| 3 | `rails_table_preferences` | package-entrypoint UI / metadata PR を、docs-only sync と分けて見る。候補は open `rails_table_preferences#1481`, `#1478`, `#1406`, `#1305`、merged docs-only `#1484` | `#1484` は docs sync evidenceで、downstream bump の主目的にしない。public-ish metadata / UI PR は human review と merge 後 main 再確認を待つ | `admin/document_sets` editor / table / filter / preset / mounted engine save。preset selector search や width / editor metadataは current wave採用後に representative admin list を選び直す | `#789` の known-good判断と混ぜず、PR bodyまたは child issue commentに from/to/smoke/rollbackを残す |

## Readiness Notes

### rails_fields_kit

- `#1480` は rendered table filter metadata reader の replacement PRです。`mergeable:true` で、PR本文上の CI は lint / rspec / gem_package / JavaScript Node 22 / 24 / Rails compatibility が success と記録されています。docs-portalでは table metadata canary候補として扱いますが、merge前に current supportとは書きません。
- `#1472` は rendered error_surface placeholder reader の replacement PRです。package-root helper family の一部として見る候補ですが、docs-portal の direct canaryは RFK form smokeとは分けます。
- `#1476` は grouped select option metadata境界です。`admin/document_sets` formの選択肢 smokeに近い候補ですが、custom option HTML / optgroup attributes は非対象として扱います。
- `#1481` は `rfk_search_with` match strategyです。host app側の remote-search / controller-helper確認が必要な場合だけ current wave に含めます。default contains維持を確認対象にし、PostgreSQL固有検索や authorizationは含めません。
- `#1471` は `rfk_range_field` native wrapperです。docs-portal側に直接の代表画面が薄いため、今回の downstream bump主目的からは外し、次 waveまたはscreen adoption候補に回します。

### tree_view

- `#1872` と `#1873` は merge済み docs / smoke evidenceとして読めます。ただしこれは target SHA決定ではなく、docs reader journeyとdemo boundaryの導線 evidenceです。
- `#1835` と `#1847` は public event detail expansion候補です。どちらも open PRなので、docs-portalの current supportとは書かず、merge後に文書ツリーの persisted state / event detail smokeと紐づけます。
- `#1874` は `row_data_builder` / row status data boundaryのopen PRです。TreeView側のhost-app metadata boundaryとして重要ですが、manifest-backed return-shape schemaへ昇格しない前提が人間レビュー待ちです。
- TreeViewのcurrent waveは、先に merged docs evidenceを読み、event detail / row status dataはmerge後に downstream smokeへつなげる順にします。

### rails_table_preferences

- `#1484` は merge済み docs-only CHANGELOG syncです。release narrativeの evidenceとして読めますが、docs-portal bump targetの主目的にはしません。
- `#1481` は preset selector searchです。package-entrypoint-only UI affordanceで、browser-capable reviewが必要な候補として扱います。
- `#1478` は manual column editor metadataです。`#1454` replacementで、current main起点の metadata expansionとして読む候補です。
- `#1406` は filter input attributesです。server-side validationや query executionを変えない browser affordance候補として扱います。
- `#1305` は column width min/max metadataです。public column metadataのadditive expansionで、known-good revision判断は `#789` と分けます。
- RTPは波及範囲が広いため、open PRを current supportへ先取りせず、`#789` の known-good判断と docs-portal representative smokeが揃ってから bump候補にします。

## Decision

1. RFKを先に読む。ただし `#1471` は次 waveに分け、table metadata reader / package-root helper / grouped select / search match strategyのうち docs-portalに効く候補だけを merge後 mainで再確認する。
2. TreeViewは merged docs evidenceを先に取り込み、event detail / row status dataのopen PRは merge後に sidebar tree / detail tree / persisted state smokeへ接続する。
3. RTPは docs-only syncと package-entrypoint UI / metadata PRを分ける。`#789` の known-good revision判断を先取りせず、代表 smokeは `admin/document_sets` editor / table / filter / preset / mounted engine saveを基本にする。
4. target SHAはこの文書では固定しない。各 bump PRで from / to SHA、代表 smoke、rollback targetを1箇所に記録する。
5. open PRを current supportとして書く必要が出た場合は、その時点で止める。

## Boundaries

- `Gemfile` / `Gemfile.lock` は変更しない。
- upstream PRのコードレビュー、merge判断、public API採否の最終判断はしない。
- 3 gem同時bump、screen-by-screen adoption、TreeView x RTP canary `#2825`、RTP x RFK canary `#2740`、visual evidence一括取得はこのdecision recordに含めない。
- docs-portal固有の route、permission、business label、table key、field paramsは downstream evidenceとして扱い、upstream gem responsibilityへ押し戻さない。

## Verification Notes

- 変更は docs-only decision recordに閉じる。
- source reviewでは、open PRを current supportと断定する表現がないことを確認する。
- diff reviewでは、`Gemfile` / `Gemfile.lock` と runtime codeに触れていないことを確認する。
