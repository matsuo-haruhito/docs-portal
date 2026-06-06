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
end
