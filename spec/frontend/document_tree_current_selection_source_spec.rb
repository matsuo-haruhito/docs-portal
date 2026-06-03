require "rails_helper"

RSpec.describe "document tree current selection source" do
  let(:tree_source) { Rails.root.join("app/views/documents/_tree.html.erb").read }
  let(:columns_source) { Rails.root.join("app/views/documents/_tree_columns.html.erb").read }
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

  it "keeps the progressive tree refresh click boundaries" do
    expect(controller_source).to include("if (event.target.closest(\".tree-toggle\")) return")
    expect(controller_source).to include("const link = event.target.closest(\"a[data-tree-refresh-url]\")")
    expect(controller_source).to include("event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0")
    expect(controller_source).to include("window.Turbo?.renderStreamMessage(html)")
  end
end
