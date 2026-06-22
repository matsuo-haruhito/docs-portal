require "rails_helper"

RSpec.describe "image and PDF preview tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:image_preview_source) { read_source("app/frontend/lib/image_preview_tools.js") }
  let(:pdf_preview_source) { read_source("app/frontend/lib/pdf_preview_tools.js") }

  it "keeps image preview keyboard shortcuts, editable guards, and persistence boundaries" do
    aggregate_failures do
      expect(image_preview_source).to include('function isEditableTarget(target)')
      expect(image_preview_source).to include('return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable')
      expect(image_preview_source).to include('const storageKey = `docsPortal.imagePreview:${container.dataset.imagePreviewStorageKey || window.location.pathname}`')
      expect(image_preview_source).to include('return { fit: true, zoom: 1, rotation: 0, ...JSON.parse(window.localStorage.getItem(storageKey) || "{}") }')
      expect(image_preview_source).to include('return { fit: true, zoom: 1, rotation: 0 }')
      expect(image_preview_source).to include('const writeState = (state) => window.localStorage.setItem(storageKey, JSON.stringify(state))')
      expect(image_preview_source).to include('const clampZoom = (value) => Math.min(4, Math.max(0.25, value))')
      expect(image_preview_source).to include('const normalizeRotation = (value) => ((Number(value) % 360) + 360) % 360')
      expect(image_preview_source).to include('if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || isEditableTarget(event.target)) return')
      expect(image_preview_source).to include('["+", "=", "-", "_", "0", "f", "F", "[", "]"].includes(event.key)')
      expect(image_preview_source).to include('event.preventDefault()')
      expect(image_preview_source).to include('case "+":')
      expect(image_preview_source).to include('case "=":')
      expect(image_preview_source).to include('setZoom((Number(state.zoom) || 1) + 0.25)')
      expect(image_preview_source).to include('case "-":')
      expect(image_preview_source).to include('case "_":')
      expect(image_preview_source).to include('setZoom((Number(state.zoom) || 1) - 0.25)')
      expect(image_preview_source).to include('case "0":')
      expect(image_preview_source).to include('setZoom(1)')
      expect(image_preview_source).to include('case "f":')
      expect(image_preview_source).to include('case "F":')
      expect(image_preview_source).to include('toggleFit()')
      expect(image_preview_source).to include('case "[":')
      expect(image_preview_source).to include('setRotation((Number(state.rotation) || 0) - 90)')
      expect(image_preview_source).to include('case "]":')
      expect(image_preview_source).to include('setRotation((Number(state.rotation) || 0) + 90)')
      expect(image_preview_source).to include('fitToggle.setAttribute("aria-pressed", String(state.fit))')
      expect(image_preview_source).to include('fitToggle.textContent = state.fit ? "画面に合わせる" : "倍率表示中"')
      expect(image_preview_source).to include('const scaleLabel = state.fit ? "画面幅" : `${Math.round(zoom * 100)}%`')
      expect(image_preview_source).to include('const rotationLabel = rotation === 0 ? "回転なし" : `${rotation}°回転`')
      expect(image_preview_source).to include('status.textContent = `${scaleLabel} / ${rotationLabel}`')
    end
  end

  it "keeps PDF preview height shortcut, editable guard, and status persistence boundaries" do
    aggregate_failures do
      expect(pdf_preview_source).to include('function isEditableTarget(target)')
      expect(pdf_preview_source).to include('return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable')
      expect(pdf_preview_source).to include('const storageKey = `docsPortal.pdfPreviewHeight:${container.dataset.pdfPreviewStorageKey || window.location.pathname}`')
      expect(pdf_preview_source).to include('const readLarge = () => window.localStorage.getItem(storageKey) === "large"')
      expect(pdf_preview_source).to include('const writeLarge = (enabled) => window.localStorage.setItem(storageKey, enabled ? "large" : "normal")')
      expect(pdf_preview_source).to include('frame.style.minHeight = large ? "90vh" : "75vh"')
      expect(pdf_preview_source).to include('toggle.setAttribute("aria-pressed", String(large))')
      expect(pdf_preview_source).to include('toggle.textContent = large ? "標準高さに戻す" : "大きく表示"')
      expect(pdf_preview_source).to include('status.textContent = large ? "大きく表示しています" : "標準高さで表示しています"')
      expect(pdf_preview_source).to include('if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || isEditableTarget(event.target)) return')
      expect(pdf_preview_source).to include('if (event.key !== "h" && event.key !== "H") return')
      expect(pdf_preview_source).to include('event.preventDefault()')
      expect(pdf_preview_source).to include('toggleHeight()')
      expect(pdf_preview_source).to include('applyHeight(readLarge())')
      expect(pdf_preview_source).to include('delete container.dataset.pdfPreviewToolsReady')
    end
  end
end
