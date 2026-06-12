require "rails_helper"

RSpec.describe "site viewer iframe height source" do
  let(:view_source) { Rails.root.join("app/views/shared/site_viewer.html.slim").read }
  let(:layout_source) { Rails.root.join("app/views/layouts/application.html.slim").read }
  let(:site_viewer_iframe_height_controller_source) { Rails.root.join("app/frontend/controllers/site_viewer_iframe_height_controller.js").read }
  let(:helper_source) { Rails.root.join("app/frontend/lib/site_viewer_iframe_height.js").read }
  let(:heading_outline_source) { Rails.root.join("app/frontend/lib/site_viewer_heading_outline.js").read }
  let(:stylesheet_source) { Rails.root.join("app/frontend/entrypoints/application.css").read }
  let(:document_controller_source) { Rails.root.join("app/controllers/document_sites_controller.rb").read }
  let(:project_controller_source) { Rails.root.join("app/controllers/project_sites_controller.rb").read }

  it "marks the site viewer iframe for auto height sync" do
    expect(view_source).to include("data-docs-portal-auto-height=\"true\"")
  end

  it "refreshes iframe height sync from the dedicated controller" do
    aggregate_failures do
      expect(layout_source).to include("site-viewer-iframe-height")
      expect(site_viewer_iframe_height_controller_source).to include('import { setupSiteViewerIframeHeightSync } from "../lib/site_viewer_iframe_height"')
      expect(site_viewer_iframe_height_controller_source).to include("setupSiteViewerIframeHeightSync()")
      expect(Rails.root.join("app/frontend/controllers/preview_tools_controller.js")).not_to exist
    end
  end

  it "adds a same-origin heading outline without adding full text search" do
    aggregate_failures do
      expect(view_source).to include("data-docs-portal-heading-outline=\"true\"")
      expect(view_source).to include("data-docs-portal-heading-outline-summary=\"true\"")
      expect(view_source).to include("data-docs-portal-heading-outline-list=\"true\"")
      expect(view_source).to include("見出しを読み込み中です")
      expect(site_viewer_iframe_height_controller_source).to include('import { setupSiteViewerHeadingOutline } from "../lib/site_viewer_heading_outline"')
      expect(site_viewer_iframe_height_controller_source).to include("setupSiteViewerHeadingOutline()")
      expect(heading_outline_source).to include('const HEADING_SELECTOR = "h1, h2, h3"')
      expect(heading_outline_source).to include("frame.contentDocument || frame.contentWindow?.document")
      expect(heading_outline_source).to include("見出しを取得できませんでした")
      expect(heading_outline_source).to include("見出しはありません")
      expect(heading_outline_source).to include("heading.scrollIntoView")
      expect(heading_outline_source).not_to include("fetch(")
      expect(heading_outline_source).not_to include("localStorage")
    end
  end

  it "keeps the heading outline responsive inside the viewer shell" do
    aggregate_failures do
      expect(stylesheet_source).to include(".site-viewer-outline")
      expect(stylesheet_source).to include(".site-viewer-outline__list")
      expect(stylesheet_source).to include(".site-viewer-outline__item")
      expect(stylesheet_source).to include("@media (max-width: 960px)")
      expect(stylesheet_source).to include(".site-viewer-outline__item.is-level-2")
    end
  end

  it "keeps the parent-side helper scoped to same-origin viewer frames" do
    aggregate_failures do
      expect(helper_source).to include('const HEIGHT_MESSAGE_TYPE = "docs-portal:site-viewer-height"')
      expect(helper_source).to include('window.addEventListener("message", handleViewerHeightMessage)')
      expect(helper_source).to include('if (event.origin !== window.location.origin) return')
      expect(helper_source).to include('if (frame.contentWindow !== event.source) return')
      expect(helper_source).to include('frame.style.height = `${normalizedHeight}px`')
    end
  end

  it "keeps both embedded response hooks minimal but reactive to later height changes" do
    [document_controller_source, project_controller_source].each do |controller_source|
      aggregate_failures do
        expect(controller_source).to include('data-docs-portal-embedded-viewer')
        expect(controller_source).to include('data-docs-portal-embedded-height-sync')
        expect(controller_source).to include('window.parent.postMessage({ type: messageType, height }, window.location.origin)')
        expect(controller_source).to include("ResizeObserver")
        expect(controller_source).to include("MutationObserver")
      end
    end
  end
end
