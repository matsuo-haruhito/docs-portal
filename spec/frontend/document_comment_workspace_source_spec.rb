require "rails_helper"

RSpec.describe "document comment workspace source" do
  let(:workspace_source) { Rails.root.join("app/views/documents/_comment_workspace.html.slim").read }
  let(:workspace_stylesheet) { Rails.root.join("app/assets/stylesheets/document_comment_workspace.css").read }

  it "separates Q&A and internal review counts in the workspace summary" do
    aggregate_failures do
      expect(workspace_source).to include("document-comment-workspace__summary")
      expect(workspace_source).to include("document-comment-workspace__summary-label Q&A")
      expect(workspace_source).to include("document-comment-workspace__summary-label 確認事項")
      expect(workspace_source).to include('"未解決 #{unresolved_question_count}件"')
      expect(workspace_source).to include('"未解決 #{unresolved_review_count}件"')
      expect(workspace_source).to include("unresolved_total_count = unresolved_question_count + unresolved_review_count")
    end
  end

  it "keeps summary density readable in floating and inline layouts" do
    aggregate_failures do
      expect(workspace_stylesheet).to include(".document-comment-workspace__summary{display:grid")
      expect(workspace_stylesheet).to include("grid-template-columns:repeat(2,minmax(0,1fr))")
      expect(workspace_stylesheet).to include(".document-comment-workspace__summary-help{grid-column:1/-1")
      expect(workspace_stylesheet).to include("@media (max-width:720px)")
      expect(workspace_stylesheet).to include(".document-comment-workspace__summary{grid-template-columns:1fr}")
      expect(workspace_stylesheet).to include(".document-comment-workspace__status{display:inline-block;margin-top:4px;white-space:normal}")
      expect(workspace_stylesheet).to include(".document-comment-workspace__panel{pointer-events:auto;display:none;position:absolute;right:0;bottom:0;box-sizing:border-box")
      expect(workspace_stylesheet).to include(".document-comment-workspace__summary-item{box-sizing:border-box")
      expect(workspace_stylesheet).to include(".comment-mode-switch__input,.document-comment-tabs__input{position:absolute;width:1px;height:1px;margin:0;opacity:0;pointer-events:none}")
    end
  end

  it "keeps internal-only review cues behind the internal user guard" do
    aggregate_failures do
      expect(workspace_source).to include("if current_user.internal?")
      expect(workspace_source).to include("show_reviews: current_user.internal?")
      expect(workspace_source).to include("document-comment-workspace__summary-item--internal")
      expect(workspace_source).to include("document-comment-tabs__panel--review")
      expect(workspace_source).to include("show_reviews: true")
    end
  end

  it "keeps comment search in the workspace while adding the summary" do
    aggregate_failures do
      expect(workspace_source).to include("document-comment-search")
      expect(workspace_source).to include("comment_filter_active")
      expect(workspace_source).to include("絞り込み条件に一致する未解決のコメントはありません。")
    end
  end

  it "explains unresolved tabs without implying SLA or workflow changes" do
    aggregate_failures do
      expect(workspace_source).to include("未解決タブには、未解決のQ&Aと内部向け確認事項をまとめて表示します。通知・期限・SLAを示すものではありません。")
      expect(workspace_source).to include("未解決タブには、まだ回答やクローズがされていないQ&Aを表示します。")
      expect(workspace_source).to include('span.muted = " (Q&A #{unresolved_question_count} / 確認事項 #{unresolved_review_count})"')
      expect(workspace_source).to include('= link_to "未解決Q&A", comment_tab_url.call("unresolved")')
    end
  end
end
