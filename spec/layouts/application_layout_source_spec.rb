require "rails_helper"

RSpec.describe "Application layout source" do
  it "keeps the shared layout styles out of the Slim template" do
    layout_source = Rails.root.join("app/views/layouts/application.html.slim").read

    expect(layout_source).to include('= vite_javascript_tag "application"')
    expect(layout_source).not_to include("\n    style\n")
  end

  it "loads the extracted stylesheet from the frontend entrypoint" do
    entrypoint_source = Rails.root.join("app/frontend/entrypoints/application.js").read

    expect(entrypoint_source).to include('import "./application.css"')
  end
end
