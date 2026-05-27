require "rails_helper"

RSpec.describe "site viewer iframe height source" do
  let(:view_source) { Rails.root.join("app/views/shared/site_viewer.html.slim").read }
  let(:preview_tools_source) { Rails.root.join("app/frontend/controllers/preview_tools_controller.js").read }
  let(:helper_source) { Rails.root.join("app/frontend/lib/site_viewer_iframe_height.js").read }
  let(:document_controller_source) { Rails.root.join("app/controllers/document_sites_controller.rb").read }
  let(:project_controller_source) { Rails.root.join("app/controllers/project_sites_controller.rb").read }

  it "marks the site viewer iframe for auto height sync" do
    expect(view_source).to include("data-docs-portal-auto-height=\"true\"")
  end

  it "refreshes iframe height sync from the preview tools controller" do
    aggregate_failures do
      expect(preview_tools_source).to include('import { setupSiteViewerIframeHeightSync } from "../lib/site_viewer_iframe_height"')
      expect(preview_tools_source).to include("setupSiteViewerIframeHeightSync()")
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