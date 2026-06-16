require "rails_helper"

RSpec.describe Admin::ModelBrowserCatalog do
  describe ".entries" do
    it "keeps the dashboard model observation entries stable" do
      dashboard_entries = described_class.entries.first(8)

      expect(dashboard_entries.map { |entry| [entry.key, entry.label, entry.group] }).to eq(
        [
          ["companies", "会社", :basic_master],
          ["users", "ユーザー", :basic_master],
          ["projects", "案件", :basic_master],
          ["project_memberships", "案件所属", :document_permission],
          ["documents", "文書", :document_permission],
          ["document_versions", "文書版", :document_permission],
          ["document_files", "文書ファイル", :document_permission],
          ["document_permissions", "文書権限", :document_permission]
        ]
      )
    end

    it "uses only groups that have model browser labels" do
      groups = described_class.entries.map(&:group).uniq

      expect(groups).to all(satisfy { |group| described_class::GROUP_LABELS.key?(group) })
    end

    it "keeps summary fields backed by model columns or documented safe display methods" do
      documented_safe_method_fields = {
        "document_sets.internal_only" => "DocumentSet exposes a read-only visibility predicate for model browser summary display.",
        "document_catalogs.internal_only" => "DocumentCatalog exposes a read-only visibility predicate for model browser summary display."
      }
      exposed_fields = described_class.entries.flat_map do |entry|
        entry.summary_fields.map { |field| "#{entry.key}.#{field}" }
      end
      missing_fields = described_class.entries.flat_map do |entry|
        display_record = entry.model_class.new

        entry.summary_fields.filter_map do |field|
          field_key = "#{entry.key}.#{field}"
          next if entry.model_class.columns_hash.key?(field.to_s)
          next if documented_safe_method_fields.key?(field_key) && display_record.respond_to?(field)

          "#{field_key} (#{entry.model_class.name})"
        end
      end

      expect(documented_safe_method_fields.keys - exposed_fields).to be_empty
      expect(missing_fields).to be_empty, "missing summary_fields: #{missing_fields.join(', ')}"
    end

    it "does not expose secret-like or raw diagnostic fields in summary metadata" do
      unsafe_field_patterns = [
        /(?:^|_)(?:secret|token|password)(?:_|$)/i,
        /(?:^|_)(?:authorization|headers?)(?:_|$)/i,
        /(?:^|_)(?:payload|body|raw)(?:_|$)/i,
        /(?:^|_)(?:request|response)(?:_|$)/i
      ]
      allowed_unsafe_looking_fields = {
        "webhook_deliveries.response_status" => "HTTP status code only; it does not expose response body, headers, or payload data."
      }
      exposed_fields = described_class.entries.flat_map do |entry|
        entry.summary_fields.map { |field| "#{entry.key}.#{field}" }
      end
      unsafe_fields = exposed_fields
        .select { |field| unsafe_field_patterns.any? { |pattern| field.match?(pattern) } }
        .reject { |field| allowed_unsafe_looking_fields.key?(field) }

      expect(exposed_fields).to include(*allowed_unsafe_looking_fields.keys)
      expect(unsafe_fields).to be_empty, "unsafe summary_fields: #{unsafe_fields.join(', ')}"
    end
  end

  describe ".searchable_summary_fields" do
    it "keeps representative search bounded to text columns and numeric id lookup" do
      searchable_fields_by_entry = described_class.entries.index_with do |entry|
        described_class.searchable_summary_fields(entry)
      end
      invalid_search_fields = described_class.entries.flat_map do |entry|
        searchable_fields_by_entry.fetch(entry).filter_map do |field|
          column = entry.model_class.columns_hash[field.to_s]
          association_id_field = field.to_s.end_with?("_id") && field != :public_id
          next if column && described_class::TEXT_SEARCH_COLUMN_TYPES.include?(column.type) && !association_id_field

          "#{entry.key}.#{field}"
        end
      end

      expect(searchable_fields_by_entry.fetch(described_class.fetch!("companies"))).to eq(%i[public_id name])
      expect(searchable_fields_by_entry.fetch(described_class.fetch!("projects"))).to eq(%i[code name])
      expect(searchable_fields_by_entry.fetch(described_class.fetch!("project_memberships"))).to eq(%i[public_id])
      expect(searchable_fields_by_entry.fetch(described_class.fetch!("document_permissions"))).to eq(%i[public_id])
      expect(searchable_fields_by_entry.fetch(described_class.fetch!("git_import_sources"))).to eq(%i[public_id repository_full_name branch])
      expect(searchable_fields_by_entry.fetch(described_class.fetch!("webhook_deliveries"))).to eq(%i[public_id event_type])
      expect(invalid_search_fields).to be_empty, "invalid searchable summary_fields: #{invalid_search_fields.join(', ')}"
    end
  end
end