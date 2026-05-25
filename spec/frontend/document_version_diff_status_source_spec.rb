require "rails_helper"

RSpec.describe "document version diff status source" do
  let(:detail_source) { Rails.root.join("app/views/document_versions/show.html.slim").read }
  let(:side_by_side_source) { Rails.root.join("app/views/document_versions/_side_by_side_file_review.html.slim").read }

  it "localizes diff status labels on the version detail surface" do
    aggregate_failures do
      expect(detail_source).to include('"changed" => "変更"')
      expect(detail_source).to include('"added" => "追加"')
      expect(detail_source).to include('"removed" => "削除"')
      expect(detail_source).to include('span.diff-status = diff_status_label.call(row.fetch(:status))')
      expect(detail_source).to include('span.muted = " / #{diff_status_label.call(file_diff.status)}"')
      expect(detail_source).to include('span.muted = " / #{diff_status_label.call(table_diff.status)}"')
      expect(detail_source).not_to include('row.fetch(:status).to_s.first.upcase')
      expect(detail_source).not_to include('span.muted = " / #{file_diff.status}"')
      expect(detail_source).not_to include('span.muted = " / #{table_diff.status}"')
    end
  end

  it "replaces raw english badges in the side-by-side review summary" do
    aggregate_failures do
      expect(side_by_side_source).to include('"changed" => "変更"')
      expect(side_by_side_source).to include('span.badge = diff_status_label.call(:changed)')
      expect(side_by_side_source).to include('span.badge = diff_status_label.call(:added)')
      expect(side_by_side_source).to include('span.badge = diff_status_label.call(:removed)')
      expect(side_by_side_source).not_to include('span.badge changed')
      expect(side_by_side_source).not_to include('span.badge added')
      expect(side_by_side_source).not_to include('span.badge removed')
    end
  end
end
