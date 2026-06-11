require "rails_helper"

RSpec.describe "markdown preview table tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:table_tools_source) { read_source("app/frontend/lib/markdown_preview_table_tools.js") }

  it "keeps the toolbar scoped to same-origin site viewer table wrappers" do
    aggregate_failures do
      expect(table_tools_source).to include('document.querySelectorAll("iframe.site-viewer-frame")')
      expect(table_tools_source).to include('frameDocument.querySelectorAll(".portal-table-width-frame")')
      expect(table_tools_source).to include('const table = wrapper.querySelector("table")')
      expect(table_tools_source).to include('const toolbar = wrapper.querySelector(".portal-table-width-toolbar")')
      expect(table_tools_source).to include('if (!table || !toolbar) return')
      expect(table_tools_source).to include('if (wrapper.dataset.tableSearchReady === "true") return')
      expect(table_tools_source).to include('wrapper.dataset.tableSearchReady = "true"')
      expect(table_tools_source).to include('frame.addEventListener("load", () => {')
      expect(table_tools_source).to include('frame.addEventListener("docs-portal:preview-tables-enhanced", () => {')
      expect(table_tools_source).to include("Cross-origin fallback: keep the viewer usable even if table tools cannot be injected.")
    end
  end

  it "keeps search, clear, result count, and row filtering per table" do
    aggregate_failures do
      expect(table_tools_source).to include('const searchGroup = createToolbarGroup(frameDocument, "検索")')
      expect(table_tools_source).to include('const input = frameDocument.createElement("input")')
      expect(table_tools_source).to include('input.type = "search"')
      expect(table_tools_source).to include('input.placeholder = "キーワード"')
      expect(table_tools_source).to include('input.setAttribute("aria-label", "表内を検索")')
      expect(table_tools_source).to include('count.className = "portal-table-search-count"')
      expect(table_tools_source).to include('count.setAttribute("aria-live", "polite")')
      expect(table_tools_source).to include('clearButton.textContent = "クリア"')
      expect(table_tools_source).to include('input.addEventListener("input", () => updateTableSearch(table, input, count))')
      expect(table_tools_source).to include('clearButton.addEventListener("click", () => {')
      expect(table_tools_source).to include('input.value = ""')
      expect(table_tools_source).to include('updateTableSearch(table, input, count)')
      expect(table_tools_source).to include('row.classList.toggle("portal-table-search-hidden", query.length > 0 && !rowMatched && !isHeaderRow)')
      expect(table_tools_source).to include('cell.classList.toggle("portal-table-search-match", matched)')
      expect(table_tools_source).to include('count.textContent = query.length > 0 ? `${matchCount}件` : ""')
    end
  end

  it "keeps CSV and Markdown copy actions with table-local status" do
    aggregate_failures do
      expect(table_tools_source).to include('const copyGroup = createToolbarGroup(frameDocument, "コピー")')
      expect(table_tools_source).to include('copyCsvButton.textContent = "CSV"')
      expect(table_tools_source).to include('copyMarkdownButton.textContent = "Markdown"')
      expect(table_tools_source).to include('copyStatus.className = "portal-table-search-count"')
      expect(table_tools_source).to include('copyStatus.setAttribute("aria-live", "polite")')
      expect(table_tools_source).to include('copyCsvButton.addEventListener("click", () => copyText(tableToCsv(table), copyStatus))')
      expect(table_tools_source).to include('copyMarkdownButton.addEventListener("click", () => copyText(tableToMarkdown(table), copyStatus))')
      expect(table_tools_source).to include('function tableToCsv(table)')
      expect(table_tools_source).to include('return tableRows(table).map((row) => row.map(csvEscape).join(",")).join("\\n")')
      expect(table_tools_source).to include('function tableToMarkdown(table)')
      expect(table_tools_source).to include('const separator = Array.from({ length: columnCount }, () => "---")')
      expect(table_tools_source).to include('status.textContent = "コピーしました"')
      expect(table_tools_source).to include('status.textContent = "コピーできませんでした"')
    end
  end

  it "does not widen this helper into renderer, codeblock, or embedded body rewrites" do
    aggregate_failures do
      expect(table_tools_source).not_to include("Mermaid")
      expect(table_tools_source).not_to include("Kroki")
      expect(table_tools_source).not_to include("codeblock")
      expect(table_tools_source).not_to include("DocusaurusSiteRenderer")
      expect(table_tools_source).not_to include("embedded=1")
      expect(table_tools_source).not_to include("document.body.innerHTML")
    end
  end
end
