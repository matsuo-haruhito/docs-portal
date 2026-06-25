# host app visual evidence comment guide

## 目的

このメモは、docs-portal 本体の小さな UI / copy / form 変更 PR で `実ブラウザ未確認` が残るときに、CI や request spec の成功と browser visual evidence の未取得を混同しないためのコメント書式です。

internal UI gem の static artifact、mockup、release train evidence は [internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md) を正本にします。このメモでは、docs-portal host app の admin / viewer / form / copy 変更に対して、review / follow-up queue に残す最小コメントだけを扱います。

## 対象

対象にしてよいもの:

- admin list / form / card / empty state の copy や補助 cue
- viewer / preview / dashboard の小さな表示変更
- request spec や source guard で text / selector / ARIA は固定済みだが、実ブラウザ viewport は未確認の PR
- merge 後に #3782 / #3871 のような browser visual evidence issue へ回す必要がある PR

対象外:

- Playwright、system spec、visual regression、screenshot job の導入
- screenshot 必須化や全 PR 共通 policy 化
- internal UI gem release train、upstream mockup、static visual artifact の evidence 設計
- 個別 PR の browser visual review 実施や採否判断

## 最小項目

visual evidence comment では、次を 1 セットで残します。

- `viewport`: desktop / narrow / mobile 相当のどれを見たか。未確認なら未確認と書く
- `対象 URL / params`: 画面 path、query、fixture / seed 前提、管理画面なら role 前提
- `確認した UI state`: normal / empty / filtered 0 件 / validation error / selected value / confirmation など
- `結果`: confirmed / source guard only / request spec only / not checked を分ける
- `残った不確実性`: hover、focus、実 font rendering、折り返し、実ブラウザ screenshot 未取得など

`CI success`、request spec success、source guard success は、copy や DOM contract の証拠です。layout、readability、narrow viewport、実フォントでの折り返しを確認した証拠としては扱いません。

## コメント先の使い分け

| コメント先 | 使う場面 | 書くこと | 書かないこと |
| --- | --- | --- | --- |
| PR comment | PR の merge 判断前に、確認済み evidence と未確認 surface を reviewer に見せたいとき | latest head、確認した viewport / URL / UI state、CI / request spec と visual evidence の差、残った不確実性 | follow-up issue の完了宣言、未確認 viewport の確認済み扱い |
| source Issue comment | PR では docs / source guard までで、merge 後に visual evidence が必要だと issue queue へ戻すとき | どの PR で何が入ったか、残る visual evidence の範囲、再開条件 | PR diff の詳細レビュー、別 issue の採否判断 |
| follow-up visual evidence Issue comment | #3782 / #3871 のような browser-capable 確認 queue で、実ブラウザ確認の結果を残すとき | 実 viewport、対象 URL / params、確認 state、screenshot / manual spot check の結果、残不確実性 | source spec success だけを visual confirmation として完了扱いすること |

コメント先に迷う場合は、merge 前の reviewer 向けなら PR comment、merge 後の残作業なら source Issue または follow-up visual evidence Issue に残します。同じ内容を複数箇所へ長く重複させず、リンクで辿れる形にします。

## テンプレート

```text
host app visual evidence:
- head: <commit sha or PR number>
- viewport: <desktop | narrow | mobile | not checked>
- target: <URL / params / role / seed or fixture>
- UI state: <normal | empty | filtered 0 | validation error | selected value | confirmation | other>
- result: <confirmed in browser | screenshot attached | request spec only | source guard only | not checked>
- CI / guard: <workflow run or spec/source guard evidence>
- limits: <hover/focus/font rendering/narrow viewport/screenshot not checked>
- follow-up: <none | source issue #... | visual evidence issue #...>
```

## screenshot がない場合

実ブラウザ screenshot が取れない環境では、次を代替 evidence として書けます。

- request spec: response body、status、redirect、safe fallback、field cue が current contract と合うこと
- source guard: view / helper / controller source に expected copy、ARIA、data attribute があること
- source inspection: class、wrapper、existing shared partial、known combobox / table / empty state pattern と矛盾しないこと
- manual spot check: browser-capable 環境で見た人、viewport、対象 URL / params、結果

代替 evidence は screenshot と同等ではありません。特に hover、focus ring、実 font rendering、narrow viewport の overlap、scroll / sticky / overflow は限界として残します。

## PR body への短い書き方

PR body では詳細テンプレートを全部貼らず、確認欄に次のように短く置きます。

```text
- request spec / source guard: success
- browser visual evidence: not checked in this PR
- follow-up: #3782 で desktop / narrow viewport を確認予定
```

PR comment や follow-up issue には、必要なときだけ詳細テンプレートを使います。

## 非目標

- CI green を visual approval として扱うこと
- screenshot の添付を全 PR で必須にすること
- host app の visual regression policy をこのメモで決めること
- internal UI gem の upstream visual evidence ルールをこのメモで置き換えること
