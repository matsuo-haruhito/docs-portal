require "rails_helper"

RSpec.describe "document approval requests source" do
  let(:index_source) { Rails.root.join("app/views/document_approval_requests/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/document_approval_requests_helper.rb").read }

  it "wires the index to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :document_approval_requests")
      expect(index_source).to include("document_approval_request_table_columns")
      expect(index_source).to include("rails_table_preference_settings(table_key: table_key)")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "確認依頼一覧の表示設定"')
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      created_at
      document
      title
      requester
      approver
      status
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps status tabs, section grouping, query preservation, and return_to behavior in the same view" do
    aggregate_failures do
      expect(index_source).to include('対応待ち #{@pending_count}件 / OK済み #{@approved_count}件 / Cancel済み #{@cancelled_count}件')
      expect(index_source).to include("query_path_params = @query.present? ? { q: @query } : {}")
      expect(index_source).to include("clear_search_params = @status_filter.present? ? { status: @status_filter } : {}")
      expect(index_source).to include("list_path.call(query_path_params.merge(status: :pending))")
      expect(index_source).to include("@document_approval_request_sections.each")
      expect(index_source).to include("document_approval_request_path(request, return_to: current_list_path)")
      expect(helper_source).to include('label: "依頼者"')
      expect(helper_source).to include('label: "確認相手"')
    end
  end
end
