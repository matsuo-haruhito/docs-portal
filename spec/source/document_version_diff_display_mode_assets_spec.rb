require "rails_helper"

RSpec.describe "Document version diff display mode assets" do
  let(:view_source) { Rails.root.join("app/views/document_versions/show.html.slim").read }
  let(:entrypoint_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:stylesheet_source) { Rails.root.join("app/frontend/entrypoints/document_version_diff_display_mode.css").read }

  it "keeps diff display mode rules in a stylesheet asset instead of inline view markup" do
    expect(view_source).not_to include("style\n  | .diff-display-mode")
    expect(view_source).not_to include(".diff-display-mode__input:checked + .diff-display-mode__label")

    expect(entrypoint_source).to include('import "./document_version_diff_display_mode.css"')
    expect(stylesheet_source).to include(".diff-display-mode__label")
    expect(stylesheet_source).to include(".diff-display-mode__panel")
    expect(stylesheet_source).to include("@media (max-width: 720px)")
  end
end
