require "rails_helper"

RSpec.describe "document version tabs source contract" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_version_tabs.js").read }
  let(:entrypoint_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:show_view_source) { Rails.root.join("app/views/document_versions/show.html.slim").read }

  it "mounts document version tabs through Stimulus instead of global load listeners" do
    aggregate_failures do
      expect(controller_source).to include('import { Controller } from "@hotwired/stimulus"')
      expect(controller_source).to include("export default class DocumentVersionTabsController extends Controller")
      expect(controller_source).not_to include('document.addEventListener("turbo:load"')
      expect(controller_source).not_to include('document.addEventListener("DOMContentLoaded"')
      expect(controller_source).not_to include("querySelectorAll('nav.markdown-mode-tabs")

      expect(entrypoint_source).to include('import DocumentVersionTabsController from "../controllers/document_version_tabs"')
      expect(entrypoint_source).to include('application.register("document-version-tabs", DocumentVersionTabsController)')
      expect(entrypoint_source).not_to include('import "../controllers/document_version_tabs"')

      expect(show_view_source).to include('nav.markdown-mode-tabs data-controller="document-version-tabs" aria-label="版詳細ナビゲーション"')
    end
  end

  it "keeps hash mapping, accessibility, and keyboard behavior stable" do
    aggregate_failures do
      expect(controller_source).to include('"#markdown-line-diff": "version-diff"')
      expect(controller_source).to include('"#html-rendered-diff": "version-diff"')
      expect(controller_source).to include('"#html-table-cell-diff": "version-diff"')
      expect(controller_source).to include('"#side-by-side-file-review": "side-by-side-file-review"')
      expect(controller_source).to include('"#version-files": "version-files"')
      expect(controller_source).to include('"#version-info": "version-info"')

      expect(controller_source).to include('nav.setAttribute("role", "tablist")')
      expect(controller_source).to include('tab.setAttribute("role", "tab")')
      expect(controller_source).to include('panel.setAttribute("role", "tabpanel")')
      expect(controller_source).to include("ArrowLeft: -1")
      expect(controller_source).to include("ArrowRight: 1")
      expect(controller_source).to include('Home: "first"')
      expect(controller_source).to include('End: "last"')
    end
  end

  it "binds hashchange within the controller lifecycle" do
    aggregate_failures do
      expect(controller_source).to include("window.addEventListener(\"hashchange\", this.hashChangeHandler)")
      expect(controller_source).to include("window.removeEventListener(\"hashchange\", this.hashChangeHandler)")
      expect(controller_source).to include("disconnect()")
    end
  end

  it "reuses already wrapped panels on reconnect" do
    aggregate_failures do
      expect(controller_source).to include("function existingPanelMap()")
      expect(controller_source).to include('const enhanced = this.element.dataset.versionTabsEnhanced === "true"')
      expect(controller_source).to include("this.panelMap = enhanced ? existingPanelMap() : buildPanelMap()")
      expect(controller_source).to include("if (!enhanced)")
      expect(controller_source).to include('this.element.dataset.versionTabsEnhanced = "true"')
    end
  end
end
