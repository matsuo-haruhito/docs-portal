require "rails_helper"

RSpec.describe Admin::DashboardHelper do
  def diagnostic_check(key, status: :ok)
    ApplicationConfigurationDiagnostic::Check.new(
      key: key,
      label: "#{key} label",
      status: status,
      message: "#{key} message",
      detail: nil
    )
  end

  describe "#configuration_diagnostic_category_label" do
    it "groups representative diagnostic keys by operation category" do
      aggregate_failures do
        expect(helper.configuration_diagnostic_category_label(diagnostic_check("DATABASE_HOST"))).to eq("環境変数")
        expect(helper.configuration_diagnostic_category_label(diagnostic_check("SECRET_KEY_BASE"))).to eq("秘密値")
        expect(helper.configuration_diagnostic_category_label(diagnostic_check("storage.document_files"))).to eq("Storage")
        expect(helper.configuration_diagnostic_category_label(diagnostic_check("docusaurus.workspace"))).to eq("Workspace")
        expect(helper.configuration_diagnostic_category_label(diagnostic_check("KROKI_ENDPOINT"))).to eq("Workspace")
      end
    end
  end

  describe "#configuration_diagnostic_status_label" do
    it "keeps ok, warning, and error states scan-friendly" do
      aggregate_failures do
        expect(helper.configuration_diagnostic_status_label(:ok)).to eq("OK")
        expect(helper.configuration_diagnostic_status_label(:warning)).to eq("警告")
        expect(helper.configuration_diagnostic_status_label(:error)).to eq("エラー")
      end
    end
  end

  describe "#configuration_diagnostic_status_badge_class" do
    it "uses distinct badge classes for each severity" do
      aggregate_failures do
        expect(helper.configuration_diagnostic_status_badge_class(:ok)).to include("bg-green-100", "text-green-800")
        expect(helper.configuration_diagnostic_status_badge_class(:warning)).to include("bg-yellow-100", "text-yellow-800")
        expect(helper.configuration_diagnostic_status_badge_class(:error)).to include("bg-red-100", "text-red-800")
      end
    end
  end
end
