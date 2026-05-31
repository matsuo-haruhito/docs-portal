require "rails_helper"

RSpec.describe Admin::DocumentsHelper, type: :helper do
  describe "#admin_document_active_filter_summaries" do
    it "renders active filters with readable labels" do
      category = Document.categories.keys.first
      document_kind = Document.document_kinds.keys.first
      visibility_policy = Document.visibility_policies.keys.first

      summaries = helper.admin_document_active_filter_summaries(
        {
          q: " Quarterly Docs ",
          category: category,
          document_kind: document_kind,
          visibility_policy: visibility_policy,
          archived: "archived",
          retention: "due",
          discard: "missing"
        }
      )

      expect(summaries).to eq([
        "キーワード: Quarterly Docs",
        "カテゴリ: #{helper.localized_label("documents.category", category)}",
        "種別: #{helper.localized_label("documents.document_kind", document_kind)}",
        "公開範囲: #{helper.localized_label("documents.visibility_policy", visibility_policy)}",
        "アーカイブ状態: アーカイブ済みのみ",
        "保管期限: 保管期限切れ",
        "廃棄候補: 廃棄候補なし"
      ])
    end

    it "does not expose raw option values when unknown values are present" do
      summaries = helper.admin_document_active_filter_summaries(
        {
          category: "unexpected-category",
          document_kind: "unexpected-kind",
          visibility_policy: "unexpected-visibility",
          archived: "unexpected-archive",
          retention: "unexpected-retention",
          discard: "unexpected-discard"
        }
      )

      expect(summaries).to eq([
        "カテゴリ: 指定あり",
        "種別: 指定あり",
        "公開範囲: 指定あり",
        "アーカイブ状態: 指定あり",
        "保管期限: 指定あり",
        "廃棄候補: 指定あり"
      ])
    end
  end
end