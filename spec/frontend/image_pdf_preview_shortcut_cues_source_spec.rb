require "rails_helper"

RSpec.describe "image and PDF preview shortcut cues source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:image_preview_source) { read_source("app/frontend/lib/image_preview_tools.js") }
  let(:pdf_preview_source) { read_source("app/frontend/lib/pdf_preview_tools.js") }

  it "keeps image preview shortcut cues on button titles and accessible labels" do
    aggregate_failures do
      expect(image_preview_source).to include('function setShortcutCue(button, label, shortcut)')
      expect(image_preview_source).to include('button.setAttribute("aria-label", `${label} (ショートカット: ${shortcut})`)')
      expect(image_preview_source).to include('button.title = `${label} (${shortcut})`')
      expect(image_preview_source).to include('setShortcutCue(zoomOutButton, "縮小", "- / _")')
      expect(image_preview_source).to include('setShortcutCue(zoomResetButton, "倍率をリセット", "0")')
      expect(image_preview_source).to include('setShortcutCue(zoomInButton, "拡大", "+ / =")')
      expect(image_preview_source).to include('setShortcutCue(rotateLeftButton, "左に90度回転", "[")')
      expect(image_preview_source).to include('setShortcutCue(rotateRightButton, "右に90度回転", "]")')
      expect(image_preview_source).to include('fitToggle.setAttribute("aria-label", `${fitToggleLabel} (ショートカット: F)`)')
      expect(image_preview_source).to include('fitToggle.title = `${fitToggleLabel} (F)`')
    end
  end

  it "keeps image preview shortcut behavior unchanged while adding cues" do
    aggregate_failures do
      expect(image_preview_source).to include('["+", "=", "-", "_", "0", "f", "F", "[", "]"].includes(event.key)')
      expect(image_preview_source).to include('case "+":')
      expect(image_preview_source).to include('case "=":')
      expect(image_preview_source).to include('case "-":')
      expect(image_preview_source).to include('case "_":')
      expect(image_preview_source).to include('case "0":')
      expect(image_preview_source).to include('case "f":')
      expect(image_preview_source).to include('case "F":')
      expect(image_preview_source).to include('case "[":')
      expect(image_preview_source).to include('case "]":')
      expect(image_preview_source).to include('const storageKey = `docsPortal.imagePreview:${container.dataset.imagePreviewStorageKey || window.location.pathname}`')
    end
  end

  it "keeps PDF preview height shortcut cue on the toggle button without changing behavior" do
    aggregate_failures do
      expect(pdf_preview_source).to include('const toggleLabel = large ? "標準高さに戻す" : "大きく表示"')
      expect(pdf_preview_source).to include('toggle.setAttribute("aria-label", `${toggleLabel} (ショートカット: h / H)`)')
      expect(pdf_preview_source).to include('toggle.title = `${toggleLabel} (h / H)`')
      expect(pdf_preview_source).to include('if (event.key !== "h" && event.key !== "H") return')
      expect(pdf_preview_source).to include('const storageKey = `docsPortal.pdfPreviewHeight:${container.dataset.pdfPreviewStorageKey || window.location.pathname}`')
      expect(pdf_preview_source).to include('frame.style.minHeight = large ? "90vh" : "75vh"')
    end
  end
end
