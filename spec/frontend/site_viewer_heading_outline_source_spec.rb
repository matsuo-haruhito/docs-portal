require "rails_helper"

RSpec.describe "Site viewer heading outline source" do
  let(:outline_source) { Rails.root.join("app/frontend/lib/site_viewer_heading_outline.js").read }
  let(:controller_source) { Rails.root.join("app/frontend/controllers/site_viewer_iframe_height_controller.js").read }
  let(:view_source) { Rails.root.join("app/views/shared/site_viewer.html.slim").read }

  it "keeps the outline wired through the shared viewer shell and controller" do
    aggregate_failures do
      expect(view_source).to include('.site-viewer-outline data-docs-portal-heading-outline="true" aria-live="polite"')
      expect(view_source).to include('span.muted data-docs-portal-heading-outline-summary="true" 見出しを読み込み中です')
      expect(view_source).to include('.site-viewer-outline__list data-docs-portal-heading-outline-list="true" role="list"')
      expect(view_source).to include('data-docs-portal-heading-outline="true"')
      expect(controller_source).to include('import { setupSiteViewerHeadingOutline } from "../lib/site_viewer_heading_outline"')
      expect(controller_source).to include("setupSiteViewerHeadingOutline()")
    end
  end

  it "limits the collected headings to non-empty h1 through h3 inside the iframe" do
    aggregate_failures do
      expect(outline_source).to include('const HEADING_SELECTOR = "h1, h2, h3"')
      expect(outline_source).to include('frame.contentDocument || frame.contentWindow?.document || null')
      expect(outline_source).to include('frameDocument.querySelectorAll(HEADING_SELECTOR)')
      expect(outline_source).to include('filter((heading) => headingText(heading))')
      expect(outline_source).not_to include("h4")
      expect(outline_source).not_to include("querySelectorAll(\"h1, h2, h3, h4")
    end
  end

  it "caps visible heading buttons and explains omitted headings in the summary" do
    aggregate_failures do
      expect(outline_source).to include("const MAX_VISIBLE_HEADINGS = 24")
      expect(outline_source).to include("headings.slice(0, MAX_VISIBLE_HEADINGS)")
      expect(outline_source).to include("const omittedCount = Math.max(headings.length - MAX_VISIBLE_HEADINGS, 0)")
      expect(outline_source).to include('`${headings.length}件の見出し（先頭${MAX_VISIBLE_HEADINGS}件を表示・後続は本文スクロールで確認）`')
      expect(outline_source).to include('`${headings.length}件の見出し（クリックで本文位置へ移動）`')
    end
  end

  it "keeps the fallback states visible without breaking the viewer body" do
    aggregate_failures do
      expect(outline_source).to include("function setOutlineState(container, message)")
      expect(outline_source).to include("container.hidden = false")
      expect(outline_source).to include('setOutlineState(container, "見出しを取得できませんでした。本文側の通常スクロールで確認してください。")')
      expect(outline_source).to include('setOutlineState(container, "見出しはありません。本文側の通常スクロールで確認してください。")')
      expect(outline_source).to include("if (!frameDocument?.body)")
      expect(outline_source).to include("if (!list || headings.length === 0)")
    end
  end

  it "keeps click behavior scoped to heading scroll, iframe focus, and a lightweight active cue" do
    aggregate_failures do
      expect(outline_source).to include('button.type = "button"')
      expect(outline_source).to include('button.className = `site-viewer-outline__item is-level-${headingLevel(heading)}`')
      expect(outline_source).to include('heading.scrollIntoView({ behavior: "smooth", block: "start" })')
      expect(outline_source).to include("frame.contentWindow?.focus()")
      expect(outline_source).to include("function activateHeadingButton(button)")
      expect(outline_source).to include('button.classList.add("is-active")')
      expect(outline_source).to include('button.setAttribute("aria-current", "location")')
      expect(outline_source).not_to include("scrollspy")
      expect(outline_source).not_to include("IntersectionObserver")
    end
  end
end
