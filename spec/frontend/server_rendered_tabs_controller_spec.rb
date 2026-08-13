# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Server-rendered tabs controller behavior smoke" do
  it "registers the shared controller in the Vite entrypoint" do
    entrypoint_source = Rails.root.join("app/frontend/entrypoints/application.js").read

    expect(entrypoint_source).to include('import ServerRenderedTabsController from "../controllers/server_rendered_tabs_controller"')
    expect(entrypoint_source).to include('application.register("server-rendered-tabs", ServerRenderedTabsController)')
  end

  it "runs the Node behavior smoke for manual tab activation" do
    stdout, stderr, status = Open3.capture3(
      "npx",
      "--no-install",
      "tsx",
      "--test",
      Rails.root.join("spec/frontend/server_rendered_tabs_controller.test.ts").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
