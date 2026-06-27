require "rails_helper"

RSpec.describe "Document comment Q&A runbook references" do
  DOC_COMMENT_QA_REPO_ROOT = Rails.root
  DOC_COMMENT_QA_RUNBOOK_PATH = DOC_COMMENT_QA_REPO_ROOT.join("docs/文書コメント・Q&A運用runbook.md")

  DOC_COMMENT_QA_IMPLEMENTATION_REFERENCES = [
    {
      label: "DocumentReviewComment",
      path: "app/models/document_review_comment.rb",
      source_signals: ["class DocumentReviewComment", "public_thread?", "qa_status_label", "resolve!"]
    },
    {
      label: "DashboardController",
      path: "app/controllers/dashboard_controller.rb",
      source_signals: ["class DashboardController", "OPEN_QA_HANDOFF_LIMIT = 5", "open_question_handoff_threads"]
    },
    {
      label: "DocumentReviewCommentsController",
      path: "app/controllers/document_review_comments_controller.rb",
      source_signals: ["class DocumentReviewCommentsController", "COMMENT_CONTEXT_TABS", "comment_author_id", "resolve"]
    },
    {
      label: "DocumentCommentWorkspaceSearch",
      path: "app/services/document_comment_workspace_search.rb",
      source_signals: ["class DocumentCommentWorkspaceSearch", "COMMENT_QUERY_MAX_LENGTH = 100", "COMMENT_AUTHOR_OPTIONS_LIMIT = 50"]
    },
    {
      label: "DocumentCommentWorkspaceTab",
      path: "app/services/document_comment_workspace_tab.rb",
      source_signals: ["class DocumentCommentWorkspaceTab", "TABS =", "DEFAULT_TAB"]
    },
    {
      label: "Q&A workspace partial",
      path: "app/views/documents/_comment_workspace.html.slim",
      source_signals: ["comment_q", "comment_author_id", "DocumentCommentWorkspaceTab::DEFAULT_TAB"]
    },
    {
      label: "workspace handoff partial",
      path: "app/views/documents/_comment_workspace_handoff_summary.html.slim",
      source_signals: ["未解決handoff", "comment_q", "comment_author_id"]
    },
    {
      label: "dashboard open Q&A handoff spec",
      path: "spec/requests/dashboard_open_question_handoff_spec.rb",
      source_signals: ["Dashboard open Q&A handoff", "open public root Q&A"]
    },
    {
      label: "workspace handoff spec",
      path: "spec/requests/document_comment_workspace_handoff_spec.rb",
      source_signals: ["Document comment workspace handoff summary", "excludes arbitrary request query values"]
    },
    {
      label: "redirect context spec",
      path: "spec/requests/document_review_comment_redirect_context_spec.rb",
      source_signals: ["Document review comment redirect context", "comment_tab", "comment_q"]
    }
  ].freeze

  DOC_COMMENT_QA_REQUIRED_REQUEST_SPECS = %w[
    spec/requests/dashboard_open_question_handoff_spec.rb
    spec/requests/document_comment_workspace_handoff_spec.rb
    spec/requests/document_comment_workspace_search_cue_spec.rb
    spec/requests/document_review_comment_redirect_context_spec.rb
  ].freeze

  it "keeps documented source and spec paths pointing at repository files" do
    missing_paths = documented_repo_paths.reject { |path| DOC_COMMENT_QA_REPO_ROOT.join(path).exist? }

    expect(missing_paths).to be_empty, <<~MESSAGE
      docs/文書コメント・Q&A運用runbook.md lists missing implementation paths.
      Update the 確認に使う主な実装 section when moving source or specs.
      Missing paths: #{missing_paths.inspect}
    MESSAGE
  end

  it "keeps the main Q&A handoff and search entrypoints discoverable" do
    aggregate_failures do
      DOC_COMMENT_QA_IMPLEMENTATION_REFERENCES.each do |reference|
        has_runbook_reference = implementation_section.include?("`#{reference.fetch(:label)}`") ||
          implementation_section.include?("`#{reference.fetch(:path)}`")
        expect(has_runbook_reference).to be(true), "missing #{reference.fetch(:label)} / #{reference.fetch(:path)} in runbook implementation references"

        source = DOC_COMMENT_QA_REPO_ROOT.join(reference.fetch(:path)).read
        reference.fetch(:source_signals).each do |signal|
          expect(source).to include(signal), "#{reference.fetch(:path)} is missing #{signal.inspect}"
        end
      end

      DOC_COMMENT_QA_REQUIRED_REQUEST_SPECS.each do |path|
        expect(implementation_section).to include("`#{path}`")
      end
    end
  end

  it "keeps the runbook focused on current behavior boundaries" do
    aggregate_failures do
      expect(runbook_source).to include("通知、メール、SLA、回答期限、自動エスカレーションはこの runbook の対象外")
      expect(runbook_source).to include("通知、担当割当、SLA、ack、自動エスカレーション、状態更新を行うものではありません")
      expect(runbook_source).to include("external user には internal-only の確認事項")
      expect(runbook_source).to include("現時点では、saved search、pagination、投稿者 remote search、通知、SLA、回答期限、自動エスカレーションは current support として扱いません")
    end
  end

  def runbook_source
    DOC_COMMENT_QA_RUNBOOK_PATH.read
  end

  def implementation_section
    section = runbook_source[/^## 確認に使う主な実装\n(.*)\z/m, 1]
    raise "docs/文書コメント・Q&A運用runbook.md is missing 確認に使う主な実装" unless section

    section
  end

  def documented_repo_paths
    implementation_section.scan(/`((?:app|spec)\/[^`]+)`/).flatten.uniq
  end
end
