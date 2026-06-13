require "rails_helper"

RSpec.describe Admin::DocumentUsageReportsHelper do
  describe "usage row cues" do
    it "labels unused, read-confirmation-only, and used rows separately" do
      unused = { used: false, view_count: 0, download_count: 0, read_confirmation_count: 0 }
      read_confirmation_only = { used: true, view_count: 0, download_count: 0, read_confirmation_count: 2 }
      used = { used: true, view_count: 1, download_count: 0, read_confirmation_count: 0 }

      aggregate_failures do
        expect(helper.document_usage_report_usage_state(unused)).to eq(:unused)
        expect(helper.document_usage_report_usage_badge_label(unused)).to eq("未利用")
        expect(helper.document_usage_report_usage_hint(unused)).to eq("期間内の閲覧・DL・既読確認なし（期間外の実績は含みません）")

        expect(helper.document_usage_report_usage_state(read_confirmation_only)).to eq(:read_confirmation_only)
        expect(helper.document_usage_report_usage_badge_label(read_confirmation_only)).to eq("既読のみ")
        expect(helper.document_usage_report_usage_hint(read_confirmation_only)).to eq("閲覧・DLはなく、既読確認の内訳を確認")

        expect(helper.document_usage_report_usage_state(used)).to eq(:used)
        expect(helper.document_usage_report_usage_badge_label(used)).to eq("利用あり")
        expect(helper.document_usage_report_usage_hint(used)).to be_nil
      end
    end

    it "keeps each usage cue visually distinct" do
      aggregate_failures do
        expect(helper.document_usage_report_usage_badge_class(used: false)).to include("bg-gray-100", "text-gray-700")
        expect(helper.document_usage_report_usage_badge_class(used: true, view_count: 0, download_count: 0, read_confirmation_count: 1)).to include("bg-amber-100", "text-amber-800")
        expect(helper.document_usage_report_usage_badge_class(used: true, view_count: 1)).to include("bg-green-100", "text-green-800")
      end
    end
  end
end
