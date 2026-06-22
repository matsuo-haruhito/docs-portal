require "rails_helper"

RSpec.describe "structured preview anchor target cue source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:preview_source) { read_source("app/frontend/lib/structured_preview_tools.js") }
  let(:target_cue_note) { read_source("docs/text-preview-line-anchor-target-cue.md") }

  it "keeps text preview hash targets visually separate from search matches" do
    aggregate_failures do
      expect(preview_source).to include(".line-preview__row.is-text-preview-match")
      expect(preview_source).to include("box-shadow: inset 4px 0 0 #f59e0b")
      expect(preview_source).to include(".line-preview__row:target")
      expect(preview_source).to include(".line-preview__row.is-text-preview-anchor-target")
      expect(preview_source).to include("box-shadow: inset 4px 0 0 #2563eb")
      expect(preview_source).to include("scroll-margin-top: 1rem")
    end
  end

  it "marks the current line anchor without adding visible row copy" do
    aggregate_failures do
      expect(preview_source).to include("function markTextPreviewAnchorTarget(row, active)")
      expect(preview_source).to include('row.classList.toggle("is-text-preview-anchor-target", active)')
      expect(preview_source).to include('row.setAttribute("aria-current", "location")')
      expect(preview_source).to include('row.removeAttribute("aria-current")')
      expect(preview_source).to include("markTextPreviewAnchorTarget(row, targetId.length > 0 && row.id === targetId)")
      expect(preview_source).to include("rows.forEach((row) => markTextPreviewAnchorTarget(row, false))")
    end
  end

  it "keeps existing text preview search, copy, and hashchange behavior in place" do
    aggregate_failures do
      expect(preview_source).to include('window.addEventListener("hashchange", updateAnchorTarget)')
      expect(preview_source).to include('window.removeEventListener("hashchange", updateAnchorTarget)')
      expect(preview_source).to include('row.classList.toggle("is-text-preview-match", matched)')
      expect(preview_source).to include('if (event.key === "/" && !isEditableTarget(event.target))')
      expect(preview_source).to include('if (event.key === "Escape" && document.activeElement === input)')
      expect(preview_source).to include('await navigator.clipboard.writeText(text)')
    end
  end

  it "documents the target cue without redefining preview behavior" do
    aggregate_failures do
      expect(target_cue_note).to include("line anchor target")
      expect(target_cue_note).to include("blue")
      expect(target_cue_note).to include("search match")
      expect(target_cue_note).to include("yellow")
      expect(target_cue_note).to include("aria-current=\"location\"")
      expect(target_cue_note).to include("Current behavior remains unchanged")
    end
  end
end
