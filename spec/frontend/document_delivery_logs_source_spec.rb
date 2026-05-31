require "rails_helper"

RSpec.describe "document delivery logs source" do
  let(:index_source) { Rails.root.join("app/views/document_delivery_logs/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/document_delivery_logs_helper.rb").read }

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_key = :document_delivery_logs")
      expect(index_source).to include("document_delivery_log_table_columns")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "送付履歴一覧の表示設定"')
      expect(index_source).to include("document_delivery_log_path(log, return_to: current_delivery_logs_path)")
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      created_at
      project
      target
      recipients
      delivery_type
      status
      failure_reason
    ].each do |column_key|
      expect(index_source.scan(%(rails_table_preferences_column_key: "#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps filters and separates failure reason from status" do
    aggregate_failures do
      expect(index_source).to include("form.search_field :q")
      expect(index_source).to include("@status_filter")
      expect(index_source).to include("@delivery_type_filter")
      expect(index_source).to include("delivery_logs_limit")
      expect(index_source).to include("failure_summary = log.error_message.presence")
      expect(index_source).to include('span.muted "-"')
      expect(helper_source).to include('label: "失敗理由"')
      expect(helper_source).to include("overflow: :ellipsis")
    end
  end
end
