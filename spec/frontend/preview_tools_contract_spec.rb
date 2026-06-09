# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Preview tools frontend contracts" do
  let(:preview_controller_source) { Rails.root.join("app/frontend/controllers/preview_tools_controller.js").read }
  let(:structured_source) { Rails.root.join("app/frontend/lib/structured_preview_tools.js").read }
  let(:archive_source) { Rails.root.join("app/frontend/lib/archive_preview_tools.js").read }

  it "keeps preview-tools as the bridge for structured and archive helpers" do
    expect(preview_controller_source).to include('import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"')
    expect(preview_controller_source).to include('import { setupArchivePreviewTools } from "../lib/archive_preview_tools"')
    expect(preview_controller_source).to include("setupStructuredPreviewTools()")
    expect(preview_controller_source).to include("setupArchivePreviewTools()")
    expect(preview_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
    expect(preview_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
    expect(preview_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
    expect(preview_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
  end

  it "keeps structured and text preview keyboard setup behind per-container ready flags" do
    structured_ready_guard = structured_source.index('if (container.dataset.structuredPreviewToolsReady === "true") return')
    structured_ready_write = structured_source.index('container.dataset.structuredPreviewToolsReady = "true"')
    text_ready_guard = structured_source.index('if (container.dataset.textPreviewToolsReady === "true") return')
    text_ready_write = structured_source.index('container.dataset.textPreviewToolsReady = "true"')
    keydown_listener = structured_source.index('document.addEventListener("keydown", (event) => {')

    expect(structured_ready_guard).to be < structured_ready_write
    expect(structured_ready_write).to be < keydown_listener
    expect(text_ready_guard).to be < text_ready_write
    expect(text_ready_write).to be < structured_source.rindex('document.addEventListener("keydown", (event) => {')
    expect(structured_source.scan('document.addEventListener("keydown", (event) => {').size).to eq(2)
  end

  it "keeps structured and text preview slash focus, Escape clear, copy, and anchor behavior readable" do
    expect(structured_source).to include('if (event.key === "/" && !isEditableTarget(event.target))')
    expect(structured_source).to include("input.focus()")
    expect(structured_source).to include("input.select()")
    expect(structured_source.scan('if (event.key === "Escape" && document.activeElement === input)').size).to eq(2)
    expect(structured_source.scan("clearSearch()").size).to be >= 4
    expect(structured_source).to include("input.blur()")
    expect(structured_source).to include("navigator.clipboard.writeText")
    expect(structured_source).to include('window.addEventListener("hashchange", updateAnchorTarget)')
    expect(structured_source).to include("updateAnchorTarget()")
  end

  it "keeps archive preview safety and candidate filters tied to entry data attributes" do
    expect(archive_source).to include('return row.dataset.archivePreviewEntrySafe === "true"')
    expect(archive_source).to include('return row.dataset.archivePreviewEntryDownloadCandidate === "true"')
    expect(archive_source).to include('return row.dataset.archivePreviewEntryTextPreviewCandidate === "true"')
    expect(archive_source).to include('if (candidateFilter === "text-preview") return archiveEntryTextPreviewCandidate(row)')
    expect(archive_source).to include('if (candidateFilter === "download") return archiveEntryDownloadCandidate(row)')
    expect(archive_source).to include('if (candidateFilter === "unavailable") return !archiveEntryDownloadCandidate(row)')
    expect(archive_source).to include('if (safetyFilter === "safe") return archiveEntrySafe(row)')
    expect(archive_source).to include('if (safetyFilter === "unsafe") return !archiveEntrySafe(row)')
  end

  it "keeps archive preview filtering, active chips, sorting, copy-visible, and keydown reset behavior together" do
    ready_guard = archive_source.index('if (container.dataset.archivePreviewToolsReady === "true") return')
    ready_write = archive_source.index('container.dataset.archivePreviewToolsReady = "true"')
    keydown_listener = archive_source.index('document.addEventListener("keydown", (event) => {')

    expect(ready_guard).to be < ready_write
    expect(ready_write).to be < keydown_listener
    expect(archive_source).to include("renderActiveFilterChips(activeFilters, filterDescriptors(input, candidateFilter, directoryFilter, safetyFilter, typeFilter), clearFilter)")
    expect(archive_source).to include("const visible = textMatched && candidateMatched && directoryMatched && safetyMatched && typeMatched")
    expect(archive_source).to include(".sort((left, right) => compareRows(left, right, sortKey, sortDirection))")
    expect(archive_source).to include("const unsafeCount = visibleEntryRows.filter((row) => !archiveEntrySafe(row)).length")
    expect(archive_source).to include('if (event.key === "/" && !isEditableTarget(event.target))')
    expect(archive_source).to include('if (event.key === "Escape" && document.activeElement === input)')
    expect(archive_source).to include("resetControls()")
  end
end
