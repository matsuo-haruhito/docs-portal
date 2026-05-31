require "rails_helper"

RSpec.describe "admin generated file runs source" do
  let(:index_source) { Rails.root.join("app/views/admin/generated_file_runs/index.html.erb").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/generated_file_labels_helper.rb").read }

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_generated_file_runs")
      expect(index_source).to include("generated_file_run_table_columns")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "生成ファイル実行履歴一覧の表示設定"')
      expect(index_source).to include("retry_failed_admin_generated_file_runs_path")
      expect(index_source).to include("retry_run_admin_generated_file_run_path")
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      public_id
      status
      job_id
      generator
      output_writer
      event_source
      started_at
      finished_at
      actions
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "defines generated file run column metadata without changing filters" do
    aggregate_failures do
      expect(helper_source).to include("def generated_file_run_table_columns")
      expect(helper_source).to include('label: "実行ID"')
      expect(helper_source).to include('label: "イベント発生元"')
      expect(helper_source).to include('overflow: :ellipsis')
      expect(index_source).to include("form.label :q")
      expect(index_source).to include("form.label :status")
      expect(index_source).to include("form.label :job_id")
      expect(index_source).to include("form.label :generator")
      expect(index_source).to include("form.label :output_writer")
      expect(index_source).to include("form.label :event_source")
      expect(index_source).to include("form.label :created_from")
      expect(index_source).to include("form.label :created_to")
    end
  end
end
