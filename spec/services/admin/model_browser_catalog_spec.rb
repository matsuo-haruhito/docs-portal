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

    it "does not expose secret-like or raw payload fields in summary metadata" do
      sensitive_field_patterns = [/secret/i, /token/i, /password/i, /payload/i, /headers/i, /body/i, /raw/i]
      exposed_fields = described_class.entries.flat_map do |entry|
        entry.summary_fields.map { |field| "#{entry.key}.#{field}" }
      end

      expect(exposed_fields).not_to include(a_string_matching(Regexp.union(sensitive_field_patterns)))
    end
  end
end
