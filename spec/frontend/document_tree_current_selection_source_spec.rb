require "rails_helper"

RSpec.describe "document tree current selection source" do
  let(:tree_source) { Rails.root.join("app/views/documents/_tree.html.erb").read }
  let(:toolbar_source) { Rails.root.join("app/views/documents/_tree_toolbar.html.erb").read }
  let(:columns_source) { Rails.root.join("app/views/documents/_tree_columns.html.erb").read }
  let(:detail_sections_source) { Rails.root.join("app/views/documents/_detail_sections.html.slim").read }
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_tree_navigation_controller.js").read }

  it "marks the current tree item for visual and assistive navigation" do
    expect(columns_source).to include("item_classes = tree_item_css_class(item)")
    expect(columns_source).to include("tree_item_current = Array(item_classes).include?(\"current-node\")")
    expect(columns_source).to include("aria: { current: (\"page\" if tree_item_current) }")
    expect(columns_source).to include("upload_data[:tree_current] = \"true\" if tree_item_current")
    expect(columns_source).to include("tree-item-current-badge")
    expect(columns_source).to include("表示中")
    expect(tree_source).to include(".tree-item-current-badge")
  end

  it "keeps the current badge compact for desktop and narrow tree layouts" do
    expect(tree_source).to include(".tree-item-current-badge { display: inline-flex")
    expect(tree_source).to include("font-size: 11px")
    expect(tree_source).to include("line-height: 1.4")
    expect(tree_source).to include("white-space: nowrap")
  end

  it "explains that current selection and tree filtering are separate from document list state" do
    aggregate_failures do
      expect(toolbar_source).to include("current_document.present?")
      expect(toolbar_source).to include("表示中バッジは現在開いている文書です。")
      expect(toolbar_source).to include("検索欄は左のツリーだけを絞り込み")
      expect(toolbar_source).to include("文書一覧の条件や表示設定とは別に扱います。")
      expect(tree_source).to include(".document-tree-scope-cue")
    end
  end

  it "explains document detail state cues separately from tree current and list filters" do
    aggregate_failures do
      expect(detail_sections_source).to include(".document-detail-state-cue")
      expect(detail_sections_source).to include("本文側の「表示中」は現在開いている版や本文 context を示します。")
      expect(detail_sections_source).to include("左の文書ツリーの表示中バッジは現在文書")
      expect(detail_sections_source).to include("文書一覧の検索・表示設定は一覧画面だけの条件")
      expect(detail_sections_source).to include("一覧画面だけの条件として読み分けてください。")
    end
  end

  it "keeps the progressive tree refresh click boundaries" do
    expect(controller_source).to include("if (event.target.closest(\".tree-toggle\")) return")
    expect(controller_source).to include("const link = event.target.closest(\"a[data-tree-refresh-url]\")")
    expect(controller_source).to include("event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0")
    expect(controller_source).to include("window.Turbo?.renderStreamMessage(html)")
  end

  it "shows loading and error cues for sidebar tree refresh without changing tree-view APIs" do
    aggregate_failures do
      expect(controller_source).to include("this.showRefreshCue(\"loading\", \"文書ツリーを更新しています。\")")
      expect(controller_source).to include("文書ツリーを更新できませんでした。ページを再読み込みするか、本文側の表示を確認してください。")
      expect(controller_source).to include("cue.dataset.documentTreeRefreshCue = state")
      expect(controller_source).to include('cue.setAttribute("role", state === "error" ? "alert" : "status")')
      expect(controller_source).to include('cue.setAttribute("aria-live", state === "error" ? "assertive" : "polite")')
      expect(controller_source).to include('this.element.querySelector("[data-sidebar-content]") || document.querySelector("[data-sidebar-content]")')
      expect(controller_source).to include('container.insertBefore(cue, treePanel)')
      expect(controller_source).not_to include("treeViewLoading")
      expect(controller_source).not_to include("treeViewError")
    end
  end

  it "clears refresh cues through the same sidebar fallback container" do
    aggregate_failures do
      expect(controller_source).to include("clearRefreshCue(requestId)")
      expect(controller_source).to include("const container = this.refreshCueContainer()")
      expect(controller_source).to include('const cue = container?.querySelector("[data-document-tree-refresh-cue]")')
      expect(controller_source).not_to include('const cue = this.element.querySelector("[data-document-tree-refresh-cue]")')
    end
  end

  it "keeps refresh cues compact in the document tree partial" do
    aggregate_failures do
      expect(tree_source).to include(".document-tree-refresh-cue { margin: 0 0 8px")
      expect(tree_source).to include("border-radius: 8px")
      expect(tree_source).to include(".document-tree-refresh-cue--error")
      expect(tree_source).to include("#991b1b")
    end
  end
end