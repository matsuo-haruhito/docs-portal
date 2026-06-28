require "rails_helper"

RSpec.describe "archive preview handoff source" do
  let(:view_source) { Rails.root.join("app/views/document_files/show_archive_preview.html.slim").read }

  it "adds a read-only handoff digest to the ZIP archive preview" do
    aggregate_failures do
      expect(view_source).to include("引き継ぎ用Markdown")
      expect(view_source).to include('readonly="readonly"')
      expect(view_source).to include('data-archive-preview-handoff-digest="true"')
      expect(view_source).to include("# ZIPプレビュー確認メモ")
      expect(view_source).to include('archive_preview_query_summary = archive_path_search ? "あり（検索語は引き継ぎ用Markdownに含めません）" : "なし"')
      expect(view_source).to include('path検索: #{archive_preview_query_summary}')
      expect(view_source).to include('表示範囲: #{archive_preview_scope_note}')
      expect(view_source).to include('表示上限: #{archive_preview_limit_note}')
      expect(view_source).to include("runbook: docs/ZIPプレビューと個別ダウンロード確認runbook.md")
    end
  end

  it "keeps raw path search values out of the handoff digest" do
    aggregate_failures do
      expect(view_source).not_to include('path検索: #{@archive_preview_path_query')
      expect(view_source).to include("検索語は引き継ぎ用Markdownに含めません")
      expect(view_source).to include("secret-like value は含めません")
    end
  end

  it "keeps the digest bounded to counts, filters, and candidate summaries" do
    aggregate_failures do
      expect(view_source).to include("要注意path")
      expect(view_source).to include("テキスト確認候補")
      expect(view_source).to include("ダウンロード候補")
      expect(view_source).to include("表示中filter初期値")
      expect(view_source).to include("ZIP全件の保証ではありません")
      expect(view_source).to include("candidate 0 件は正常保証ではなく")
      expect(view_source).to include("ZIP entry本文、binary content、unsafe path の再利用、secret-like value は含めません")
    end
  end

  it "does not introduce persistence, API export, or archive action changes" do
    aggregate_failures do
      expect(view_source).not_to include("form_with url: archive_preview_handoff")
      expect(view_source).not_to include("method: :post")
      expect(view_source).not_to include("download JSON")
      expect(view_source).not_to include("CSV export")
      expect(view_source).to include("data-archive-preview-copy-visible")
      expect(view_source).to include("archive_entry_download_document_file_path")
      expect(view_source).to include("archive_entry_preview_document_file_path")
    end
  end
end
