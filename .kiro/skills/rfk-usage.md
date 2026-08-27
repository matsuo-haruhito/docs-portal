---
name: "rfk実装ガイド"
description: "docs-portalの権限付き文書ポータル用途に合わせてrails_fields_kit (RFK) をどう使うかを定める。管理画面、検索filter、権限付きremote select、RTP連携の実装規範。"
---
# RFK（rails_fields_kit）実装ガイド

このskillはRFKのAPI一覧ではない。
**docs-portalという権限付き文書ポータルで、RFKをどの入力・検索に使うか**を決める規範である。

## 0. 基本方針

**実装方針はRFK最新版を前提にする。**
現行Gemfile.lockが古い場合でも、古いrevisionの制約へ合わせてdocs-portal固有workaroundを増やさない。
最新版に必要機能があればRFKを更新し、最新版にも不足があればRFK本体を改善する。

Gemfile.lockは「今の環境でそのAPIが使えるか」の確認材料であり、このskillの目標仕様ではない。

## 1. docs-portalでRFKに担当させる範囲

docs-portalは、案件ごとの社外秘文書の公開、版管理、閲覧制御、添付配布、import / preview / build / 外部連携を扱うポータルである。

RFKの主担当:

1. **管理画面の関連master選択**
   - 案件、会社、ユーザー、文書等
   - 件数が多い場合はremote `rfk_combobox`
2. **管理一覧のfilter**
   - category / document_kind / visibility / source_authority等の固定候補は `rfk_select` / `rfk_enum_select`
   - 案件やユーザー等のremote master検索でIDとfree textを分けたい場合は `rfk_lookup`
   - plain keywordは `rfk_search_field`
3. **RTP / filter toolbarでの統一UI**
   - 通常フォームと同じsubmit contractを維持する

### RFKに担当させないもの

- ProjectMembership / DocumentPermissionによる可視範囲
- 社外ユーザーへの情報露出判定
- source authorityや公開可否の業務判断
- Git/Graph/Webhook/import/buildの実行ロジック
- remote searchの認可scopeそのもの

RFKは入力・選択UIまで。権限判定や情報露出制御をfield helperへ持ち込まない。

## 2. Helper選択

| 用途 | 第一候補 |
|---|---|
| 少数の固定候補 | `rfk_select` |
| Rails enum | `rfk_enum_select` |
| 案件・会社・ユーザー等のID選択 | `rfk_combobox` |
| ID選択 + free-text fallback検索 | `rfk_lookup` |
| plain keyword | `rfk_search_field` |
| text値＋候補 | `rfk_autocomplete` |
| 複数関連 | `rfk_multi_select` |
| user-created tag | `rfk_tags` |

**見た目ではなくsubmit contractで選ぶ。**

## 3. Remote master選択

案件等をIDで保存するフォームでは `rfk_combobox` を使う。

編集画面でassociationを既に持っているなら、**server-rendered selectedを標準**とする。
実際に文書編集ではこの形を使う。

```slim
= form.rfk_combobox :project_id,
  url: project_search_admin_documents_path(format: :json),
  selected: { value: document.project.id, text: admin_document_project_option_label(document.project) }
```

helperでselected hashを作ってもよい。

```ruby
def admin_document_project_selected_option(project)
  return nil if project.blank?
  { value: project.id, text: admin_document_project_option_label(project) }
end
```

`selected_url:` は**IDしか手元にない場合のlabel hydration**に限定する。
既にproject/associationを読み込んでいるのに表示label取得だけのrequestを増やさない。

RFK helper内部でProject/User等を検索しない。

## 4. 権限付きsearch endpoint

docs-portalではremote option APIの認可が特に重要である。
候補一覧そのものが情報露出になるため、次を必須とする。

- current user / role / membershipに基づくscope
- 選択済みID取得でも権限外recordを返さない
- 社外ユーザーにinternal metadata、raw path、provider情報等を表示labelへ混ぜない
- query長・最大件数を制限
- LIKEはsanitize + bind parameter
- 任意resource名を無制限にconstantizeしない

`selected_url:` だけ認可を緩めることは禁止。

## 5. 一覧filter

固定enum/状態filterは `rfk_select` / `rfk_enum_select` を使い、解除可能にする。

案件・会社・ユーザー等で、候補選択時はID完全一致、候補を選ばない文字列では部分一致したい場合は `rfk_lookup` を使う。

objectless GET formでも、lookup textとlookup IDを明示的に復元できることを**RFK最新版の標準contract**とする。
host appでhidden fieldやTom Select内部を直接操作して補修しない。

free-text filterはblur後も保持し、再focus後に文字単位で再編集できるUXを標準とする。

## 6. Static select / selected安全性

static collectionではremote/staticの違いを呼び出し側が毎回意識せず自然に表示できることをRFK最新版へ期待する。

collection外の `selected:` が渡ってもfield初期化全体を壊さず安全にfallbackすることもRFK側の責務とする。
古いbookmarkやURL編集のために全画面へ同じvalidation boilerplateを量産しない。

## 7. 依存field

単純な親子remote query paramは最新版RFKの `depends_on:` / `clear_on_dependency_change:` を優先する。
既存 `rfk_dependent_filter_controller` は、RFK公式機能で代替できる範囲から段階的に削る。

権限制御や業務副作用までgeneric dependencyへ押し込まない。

## 8. FilterToolbar / RTP

- form URL、hidden params、認可、検索条件生成は呼び出し側に残す
- toolbar componentはlayout責務だけ持つ
- remote comboboxは `:remote`、keywordは `:query`、enumは `:enum` 等、用途幅を使う
- 狭いtable headerへrich remote widgetを無理に埋め込まない
- RTP metadataでも通常formと同じhelper選択ルールを使う

## 9. Layout / CSS

- modal/overflow clippingはRFK公式 `dropdown_parent` 等を優先
- Tom Selectを直接初期化しない
- field属性は `html:`、wrapperは `wrapper_html:`
- global `.ts-*` overrideは最小限
- portal全体のアクセシビリティ、keyboard操作、focus復帰を壊さない

## 10. NGパターン

- 権限外recordをremote option APIが返す
- selected preloadだけ認可を緩める
- associationを既に持つのに初期label取得requestを追加する
- RFK helper内部でdomain modelを検索する
- old RFK revisionの制約をdocs-portal固有JSで固定化する
- lookup初期値・blur・refocusを独自controllerで補修する
- static/remote mappingやcollection外selected対策を全画面へコピペする
- simple dependencyに新しいbridge controllerを増やす
- UI convenienceのためにinternal metadataをoption labelへ露出する

## 11. Checklist

- [ ] RFK最新版を目標仕様として使った
- [ ] helperをsubmit contractで選んだ
- [ ] association/labelを既に持つならserver-rendered selectedを使った
- [ ] `selected_url:` が本当に必要か確認した
- [ ] remote endpointへ利用者権限scopeを適用した
- [ ] selected ID取得でも権限外recordを返していない
- [ ] option labelへ不要なinternal metadataを混ぜていない
- [ ] lookup初期値・blur・refocusをRFK標準機能で扱った
- [ ] simple dependencyはRFK公式機能を優先した
- [ ] FilterToolbar/RTPへ業務・認可責務を移していない
