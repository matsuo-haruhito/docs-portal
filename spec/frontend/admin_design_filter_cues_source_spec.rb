require "rails_helper"

RSpec.describe "admin design filter cues source" do
  let(:webhook_view_source) { Rails.root.join("app/views/admin/webhook_endpoints/index.html.slim").read }
  let(:dashboard_view_source) { Rails.root.join("app/views/admin/dashboard/index.html.slim").read }

  it "keeps Webhook endpoint pagination links contextual without changing the visible labels" do
    aggregate_failures do
      expect(webhook_view_source).to include('= link_to "前へ", admin_webhook_endpoints_path(endpoint_filter_params.merge(endpoint_page: previous_endpoint_page)), title: previous_endpoint_page_label, aria: { label: previous_endpoint_page_label }')
      expect(webhook_view_source).to include('= link_to "次へ", admin_webhook_endpoints_path(endpoint_filter_params.merge(endpoint_page: next_endpoint_page)), title: next_endpoint_page_label, aria: { label: next_endpoint_page_label }')
      expect(webhook_view_source).to include('Webhook設定一覧の#{previous_endpoint_page}ページ目へ（現在の設定検索・イベント・状態条件を保持）')
      expect(webhook_view_source).to include('Webhook設定一覧の#{next_endpoint_page}ページ目へ（現在の設定検索・イベント・状態条件を保持）')
      expect(webhook_view_source).to include("endpoint_filter_params.merge(endpoint_page: previous_endpoint_page)")
      expect(webhook_view_source).to include("endpoint_filter_params.merge(endpoint_page: next_endpoint_page)")
    end
  end

  it "keeps the filtered configuration diagnostic empty state reset cue near the warning copy" do
    aggregate_failures do
      expect(dashboard_view_source).to include("現在の絞り込み条件に一致する診断項目はありません。診断全体が正常という意味ではないため、条件を解除するか上の全体件数を確認してください。")
      expect(dashboard_view_source).to include("- if @configuration_diagnostic_filters_active\n      p.actions\n        = link_to \"絞り込み条件を解除して全診断項目を見る\", admin_root_path, class: \"button secondary\"")
      expect(dashboard_view_source).to include('= link_to "絞り込み解除", admin_root_path, class: "button secondary"')
    end
  end
end
