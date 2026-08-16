require "rails_helper"

RSpec.describe "application entrypoint source" do
  def entrypoint_source
    Rails.root.join("app/frontend/entrypoints/application.ts").read
  end

  # ExtendedRfkTomSelectController クラスおよび関連 type 定義を除外した「トップレベル」ソース
  def top_level_source
    entrypoint_source
      .sub(/^type OverlayTomSelect\b.*?^}\n/m, "")
      .sub(/^type ExtendedRfkControllerState\b.*?^}\n/m, "")
      .sub(/^class ExtendedRfkTomSelectController.*?^}\n/m, "")
  end

  it "keeps the entrypoint limited to imports, Stimulus registration, and the rfk extension class" do
    aggregate_failures do
      expect(entrypoint_source).to include('import "./application.css"')
      expect(entrypoint_source).to include('import "@hotwired/turbo-rails"')
      expect(entrypoint_source).to include('import { Application } from "@hotwired/stimulus"')
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", ExtendedRfkTomSelectController)')
      expect(entrypoint_source).to include("registerTreeViewControllers(application)")

      # トップレベル行は import / const / application.register / export / type / class 宣言のみ
      top_level_source.lines.map(&:strip).reject(&:blank?).each do |line|
        expect(line).to match(
          /\A(?:import\b|const\b|application\.register\(|export\b|type\b|\/\/|window\.Stimulus|registerTreeViewControllers\()/
        ), "application.ts top-level should stay limited to imports, type aliases, Application.start, controller registration, and the rfk extension class; found: #{line}"
      end
    end
  end

  it "keeps direct DOM setup and Tom Select initialization out of the top-level entrypoint" do
    aggregate_failures do
      expect(top_level_source).not_to match(/\bquerySelectorAll\b/),
        "DOM discovery belongs in a dedicated Stimulus controller, not application.ts top level"
      expect(top_level_source).not_to match(/\bdocument\.querySelector\b/),
        "document queries belong in a dedicated Stimulus controller, not application.ts top level"
      expect(top_level_source).not_to match(/\b(?:document|window)\.addEventListener\b/),
        "document/window listeners should be owned by a Stimulus controller lifecycle"
      expect(top_level_source).not_to match(/\bnew\s+TomSelect\b/),
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
