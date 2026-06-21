require "rails_helper"

RSpec.describe "application entrypoint source" do
  def entrypoint_source
    Rails.root.join("app/frontend/entrypoints/application.js").read
  end

  it "keeps the entrypoint limited to imports and Stimulus registration" do
    source_lines = entrypoint_source.lines.map(&:strip).reject(&:blank?)

    aggregate_failures do
      expect(entrypoint_source).to include('import "./application.css"')
      expect(entrypoint_source).to include('import "@hotwired/turbo-rails"')
      expect(entrypoint_source).to include('import { Application } from "@hotwired/stimulus"')
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')

      source_lines.each do |line|
        expect(line).to match(/\A(?:import\b|const application = Application\.start\(\)|application\.register\()/),
          "application.js should stay limited to CSS/Turbo imports, Application.start, and controller registration; move DOM setup into a Stimulus controller lifecycle"
      end
    end
  end

  it "keeps direct DOM setup and Tom Select initialization out of the entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).not_to match(/\bquerySelectorAll\b/),
        "DOM discovery belongs in a dedicated Stimulus controller, not application.js"
      expect(entrypoint_source).not_to match(/\bdocument\.querySelector\b/),
        "document queries belong in a dedicated Stimulus controller, not application.js"
      expect(entrypoint_source).not_to match(/\b(?:document|window)\.addEventListener\b/),
        "document/window listeners should be owned by a Stimulus controller lifecycle"
      expect(entrypoint_source).not_to match(/\baddEventListener\s*\(/),
        "direct event listeners should be owned by a Stimulus controller lifecycle"
      expect(entrypoint_source).not_to match(/\bnew\s+TomSelect\b/),
        "app-side Tom Select setup should use the rails-fields-kit controller registration"
    end
  end

  it "keeps the retired preview-tools bridge out of the entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).not_to include('from "../controllers/preview_tools_controller"')
      expect(entrypoint_source).not_to include('application.register("preview-tools"')
    end
  end
end
