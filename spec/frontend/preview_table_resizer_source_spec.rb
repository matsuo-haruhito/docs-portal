require "rails_helper"

RSpec.describe "preview table resizer source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:resizer_source) { read_source("app/frontend/controllers/preview_table_resizer_controller.js") }
  let(:document_sites_source) { read_source("app/controllers/document_sites_controller.rb") }
  let(:project_sites_source) { read_source("app/controllers/project_sites_controller.rb") }

  it "builds localStorage keys from the shared preview context before the table index suffix" do
    aggregate_failures do
      expect(resizer_source).to include("function previewContextKey(frame)")
      expect(resizer_source).to include("return previewContextKeyFromBody(frame) || previewContextKeyFromUrl(frame)")
      expect(resizer_source).to include('return `${prefix}:${previewContextKey(frame)}:table:${index}`')
      expect(resizer_source).to include('return frame.contentDocument?.body?.dataset?.docsPortalPreviewContextKey || null')
    end
  end

  it "keeps the URL fallback aligned with document-version scoped stable keys" do
    aggregate_failures do
      expect(resizer_source).to include('frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname')
      expect(resizer_source).to include('const versionId = url.searchParams.get("version_id") || url.pathname.match(/\/document_versions\/([^/]+)\/site(?:\/|$)/)?.[1]')
      expect(resizer_source).to include('return `document_version:${versionId}:${normalizeSitePath(decodeURIComponent(sitePath))}`')
    end
  end

  it "keeps the lightweight scroll and resize cue visible from the collapsed table toolbar" do
    aggregate_failures do
      expect(resizer_source).to include('summaryCue.className = "portal-table-width-summary-cue"')
      expect(resizer_source).to include('summaryCue.textContent = "横スクロール・列幅調整できます"')
      expect(resizer_source).to include('scroll.setAttribute("aria-label", "表は横スクロールできます")')
      expect(resizer_source).to include(".portal-table-width-summary-cue")
    end
  end

  it "keeps both embedded site responses on the same preview context marker contract" do
    aggregate_failures do
      expect(document_sites_source).to include('body["data-docs-portal-preview-context-key"] = preview_table_context_key(version:, site_path:)')
      expect(project_sites_source).to include('body["data-docs-portal-preview-context-key"] = preview_table_context_key(version:, site_path:)')
      expect(document_sites_source).to include('"document_version:#{version.public_id}:#{normalized_site_path}"')
      expect(project_sites_source).to include('"document_version:#{version.public_id}:#{normalized_site_path}"')
    end
  end
end
