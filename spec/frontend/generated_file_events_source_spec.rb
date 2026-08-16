require "rails_helper"

RSpec.describe "admin generated file events source" do
  let(:index_source) { Rails.root.join("app/views/admin/generated_file_events/index.html.slim").read }
  let(:show_source) { Rails.root.join("app/views/admin/generated_file_events/show.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/generated_file_labels_helper.rb").read }

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_generated_file_events")
      expect(index_source).to include("generated_file_event_table_columns")
      expect(index_source).to include("render ColumnSettingsComponent.new")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "生成ファイルイベント一覧の表示設定"')
      expect(index_source).to include("retry_failed_admin_generated_file_events_path")
      expect(index_source).to include("retry_dispatch_admin_generated_file_event_path")
    end
  end

  it "keeps row retry copy distinct from bulk retry while preserving detail retry copy" do
    aggregate_failures do
      expect(index_source).to include('button_to "この1件を再投入", retry_dispatch_admin_generated_file_event_path')
      expect(index_source).to include('title: "#{event.public_id} 1件を再投入キューに投入（一括再投入ではありません）"')
      expect(index_source).to include('aria: { label: "#{event.public_id} 1件を再投入キューに投入（一括再投入ではありません）" }')
      expect(index_source).not_to include('button_to "このイベントを再投入", retry_dispatch_admin_generated_file_event_path')
      expect(index_source).not_to include("このイベントを再dispatch")
      expect(index_source).not_to include("再dispatchキュー")
      expect(show_source).to include('button_to "このイベントを再投入", retry_dispatch_admin_generated_file_event_path')
      expect(show_source).to include('title: "#{@generated_file_event.public_id} を再投入キューに投入"')
      expect(show_source).to include('aria: { label: "#{@generated_file_event.public_id} を再投入キューに投入" }')
      expect(show_source).not_to include("このイベントを再dispatch")
      expect(show_source).not_to include("再dispatchキュー")
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      public_id
      status
      path
      operation
      event_source
      error_message
      occurrences_count
      scheduled_at
      processed_at
      actions
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps generated file event filters while using the shared index UI" do
    aggregate_failures do
      expect(helper_source).to include("def generated_file_event_table_columns")
      expect(helper_source).to include('label: "イベントID"')
      expect(helper_source).to include('label: "エラー"')
      expect(helper_source).to include('overflow: :ellipsis')
      expect(index_source).to include('render FilterToolbarComponent.new(label: "生成ファイルイベントの検索条件")')
      expect(index_source).to include("toolbar.with_field(size: :query)")
      expect(index_source).to include("toolbar.with_field(size: :enum)")
      expect(index_source).to include("toolbar.with_field(size: :short)")
      expect(index_source).to include("toolbar.with_field(size: :wide)")
      expect(index_source).to include("toolbar.with_field(size: :date)")
      expect(index_source).to include("form.rfk_search_field :q")
      expect(index_source).to include("form.rfk_select :status")
      expect(index_source).to include("form.rfk_select :operation")
      expect(index_source).to include("form.text_field :event_source")
      expect(index_source).to include("form.text_field :path")
      expect(index_source).to include("form.text_field :scheduled_from")
      expect(index_source).to include("form.text_field :scheduled_to")
      expect(index_source).to include('render GuidanceDisclosureComponent.new(title: "検索条件の補足")')
      expect(index_source).to include("render ListFooterComponent.new")
    end
  end
end
