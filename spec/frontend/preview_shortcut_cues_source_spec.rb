require "rails_helper"

RSpec.describe "preview shortcut cues source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:pdf_tools_source) { read_source("app/frontend/lib/pdf_preview_tools.js") }
  let(:image_tools_source) { read_source("app/frontend/lib/image_preview_tools.js") }

  it "keeps the PDF height shortcut visible without changing the persisted display contract" do
    aggregate_failures do
      expect(pdf_tools_source).to include('cue.dataset.pdfPreviewShortcutCue = "true"')
      expect(pdf_tools_source).to include("ショートカット: h / Hで高さ切替。表示高さはこのブラウザに保存されます。")
      expect(pdf_tools_source).to include('toggle.setAttribute("aria-label", `${toggleLabel} (ショートカット: h / H)`)')
      expect(pdf_tools_source).to include('const storageKey = `docsPortal.pdfPreviewHeight:${container.dataset.pdfPreviewStorageKey || window.location.pathname}`')
    end
  end

  it "keeps the image preview shortcuts visible and aligned with the existing button cues" do
    aggregate_failures do
      expect(image_tools_source).to include('cue.dataset.imagePreviewShortcutCue = "true"')
      expect(image_tools_source).to include("ショートカット: + / - 拡大縮小、0 リセット、F 画面幅、[ / ] 回転。表示はこのブラウザに保存されます。")
      expect(image_tools_source).to include('setShortcutCue(zoomOutButton, "縮小", "- / _")')
      expect(image_tools_source).to include('setShortcutCue(zoomResetButton, "倍率をリセット", "0")')
      expect(image_tools_source).to include('setShortcutCue(zoomInButton, "拡大", "+ / =")')
      expect(image_tools_source).to include('fitToggle.setAttribute("aria-label", `${fitToggleLabel} (ショートカット: F)`)')
      expect(image_tools_source).to include('setShortcutCue(rotateLeftButton, "左に90度回転", "[")')
      expect(image_tools_source).to include('setShortcutCue(rotateRightButton, "右に90度回転", "]")')
      expect(image_tools_source).to include('const storageKey = `docsPortal.imagePreview:${container.dataset.imagePreviewStorageKey || window.location.pathname}`')
    end
  end
end
