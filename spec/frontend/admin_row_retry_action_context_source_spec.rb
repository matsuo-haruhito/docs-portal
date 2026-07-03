require "rails_helper"

RSpec.describe "admin row retry action context source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:generated_file_runs_index_source) { read_source("app/views/admin/generated_file_runs/index.html.erb") }
  let(:webhook_endpoints_index_source) { read_source("app/views/admin/webhook_endpoints/index.html.slim") }

  it "keeps generated file run row retry scoped to one run with follow-up context" do
    row_retry_button_source = generated_file_runs_index_source.lines.find { |line| line.include?('button_to "この行を再実行"') }

    aggregate_failures do
      expect(generated_file_runs_index_source).to include('row_retry_confirm_message = "#{run.public_id} 1件だけを再実行します。')
      expect(generated_file_runs_index_source).to include("元の実行履歴は診断用に残り、再実行後は新しい実行IDで結果を確認します。")
      expect(generated_file_runs_index_source).to include('row_retry_action_label = "#{run.public_id} を1件だけ再実行キューに投入"')
      expect(row_retry_button_source).to include("title: row_retry_action_label")
      expect(row_retry_button_source).to include("aria: { label: row_retry_action_label }")
      expect(row_retry_button_source).to include("turbo_confirm: row_retry_confirm_message")
      expect(generated_file_runs_index_source).to include('現在の条件に一致する失敗履歴 #{bulk_retry_target_count} 件')
    end
  end

  it "keeps webhook delivery row retry confirm bounded to visible identifiers" do
    row_retry_context_source = webhook_endpoints_index_source.lines.find { |line| line.include?("retry_delivery_context =") }
    row_retry_button_source = webhook_endpoints_index_source.lines.find { |line| line.include?("retry_dispatch_admin_webhook_delivery_path") }

    aggregate_failures do
      expect(row_retry_context_source).to include("Webhook設定")
      expect(row_retry_context_source).to include("webhook_event_type_label(delivery)")
      expect(row_retry_context_source).to include("webhook_delivery_response_status_context(delivery)")
      expect(row_retry_context_source).to include("delivery #{delivery.public_id}")
      expect(webhook_endpoints_index_source).to include('retry_delivery_label = "#{retry_delivery_context} を再送"')
      expect(webhook_endpoints_index_source).not_to include('HTTP #{delivery.response_status || "-"}')
      expect(row_retry_button_source).to include("title: retry_delivery_label")
      expect(row_retry_button_source).to include("aria: { label: retry_delivery_label }")
      expect(row_retry_button_source).to include('turbo_confirm: "#{retry_delivery_context} を現在のWebhook設定で再送します。受信先側の重複処理に注意してください。"')
      expect(row_retry_button_source).not_to include("target_url")
      expect(row_retry_button_source).not_to include("error_message")
      expect(row_retry_button_source).not_to include("request_body")
      expect(row_retry_button_source).not_to include("response_body")
    end
  end
end
