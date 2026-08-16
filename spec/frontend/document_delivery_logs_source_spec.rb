require "rails_helper"

RSpec.describe "document delivery logs source" do
  let(:index_source) { Rails.root.join("app/views/document_delivery_logs/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/document_delivery_logs_helper.rb").read }

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_key = :document_delivery_logs")
      expect(index_source).to include("document_delivery_log_table_columns")
      expect(index_source).to include("render ColumnSettingsComponent.new")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include("scroll_wrapper: true")
      expect(index_source).to include("caption.table-caption.visually-hidden 送付履歴一覧")
      expect(index_source).to include('title: "送付履歴一覧の表示設定"')
      expect(index_source).to include("detail_params = { return_to: current_delivery_logs_path }.merge(current_date_filter_params)")
      expect(index_source).to include("document_delivery_log_path(log, detail_params)")
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

  it "uses the shared filter toolbar and list footer without changing filter or CSV scope" do
    aggregate_failures do
      expect(index_source).to include('render FilterToolbarComponent.new(label: "送付履歴の検索条件")')
      expect(index_source).to include("toolbar.with_field(size: :query)")
      expect(index_source.scan("toolbar.with_field(size: :enum)").size).to eq(2)
      expect(index_source.scan("toolbar.with_field(size: :date)").size).to eq(4)
      expect(index_source).to include("form.rfk_search_field :q")
      expect(index_source).to include("form.rfk_select :status")
      expect(index_source).to include("form.rfk_select :delivery_type")
      expect(index_source).to include("form.date_field :created_from")
      expect(index_source).to include("form.date_field :created_to")
      expect(index_source).to include("current_date_filter_params")
      expect(index_source).to include("delivery_logs_limit")
      expect(index_source).to include("render ListFooterComponent.new(pagination: delivery_logs_pagination")
      expect(index_source).to include("footer.with_export")
      expect(index_source).to include("current_delivery_logs_csv_path")
      expect(index_source).to include("failure_summary = log.error_message.presence")
      expect(index_source).to include('span.muted "-"')
      expect(helper_source).to include('label: "失敗理由", overflow: :ellipsis')
      expect(helper_source).to include('label: "作成日時", default_width: 130')
      expect(helper_source).to include('label: "方式", default_width: 85')
      expect(helper_source).to include('label: "状態", default_width: 80')
    end
  end
end
