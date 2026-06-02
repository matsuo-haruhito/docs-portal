module Admin::ZipImportsHelper
  ZIP_IMPORT_CLASSIFICATION_FIELDS = [
    ["カテゴリ", "category"],
    ["文書種別", "document_kind"],
    ["公開ポリシー", "visibility_policy"],
    ["スナップショット種別", "snapshot_kind"]
  ].freeze

  def import_dry_run_status_label(dry_run_or_value)
    value = dry_run_or_value.respond_to?(:status) ? dry_run_or_value.status : dry_run_or_value
    localized_label("import_dry_runs.status", value)
  end

  def import_dry_run_tree_change_type_label(change_type)
    localized_label("import_dry_run_tree_preview.change_type", change_type)
  end

  def zip_import_classification_preview_items(result)
    Array(fetch_json_value(result, "items")).map do |item|
      attributes = fetch_json_value(item, "attributes") || {}
      tags = Array(fetch_json_value(attributes, "data_classification_tags")).presence

      {
        title: fetch_json_value(item, "title").presence || fetch_json_value(attributes, "title").presence || "(タイトル未設定)",
        fields: ZIP_IMPORT_CLASSIFICATION_FIELDS.map do |label, key|
          [label, fetch_json_value(attributes, key).presence || "-"]
        end,
        matched_rules: Array(fetch_json_value(item, "matched_rules")).presence,
        data_classification_tags: tags
      }
    end
  end

  private

  def fetch_json_value(hash, key)
    return unless hash.respond_to?(:[])

    hash[key] || hash[key.to_sym]
  end
end
