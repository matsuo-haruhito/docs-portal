require "rails_helper"

RSpec.describe "document permission error surface controller source" do
  let(:source) do
    Rails.root.join("app/frontend/controllers/document_permission_error_surface_controller.js").read
  end

  it "handles selected preload failures and clears stale surface state" do
    expect(source).to include("selectedLoadError(event)")
    expect(source).to include("選択済みの文書名を読み込めませんでした。文書名を再選択してください。")
    expect(source).to include("event.detail?.surface")
    expect(source).to include("surface.hidden = false")
    expect(source).to include("surface.hidden = true")
    expect(source).to include("railsFieldsKitTomSelectErrorSurfaceIdValue")
  end
end
