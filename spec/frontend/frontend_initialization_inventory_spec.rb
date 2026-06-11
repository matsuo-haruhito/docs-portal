require "rails_helper"

RSpec.describe "Frontend initialization inventory" do
  GEM_CONTROLLER_IDENTIFIERS = [
    "rails-table-preferences",
    "rails-fields-kit--tom-select"
  ].freeze

  def read_source(path)
    Rails.root.join(path).read
  end

  def registered_controller_names(source)
    source.scan(/application\.register\("([^"]+)"/).flatten
  end

  def inventory_app_controller_names(source)
    app_section = source[/^### App 側 controller\n(?<section>.*?)(?=^## |\z)/m, :section]
    raise "App 側 controller section was not found" unless app_section

    app_section.lines.filter_map do |line|
      next unless line.start_with?("|")

      line.split("|")[1]&.match(/`([^`]+)`/)&.[](1)
    end
  end

  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }
  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }
  let(:registered_app_controllers) { registered_controller_names(entrypoint_source) - GEM_CONTROLLER_IDENTIFIERS }
  let(:inventory_app_controllers) { inventory_app_controller_names(inventory_source) }

  it "keeps the App side controller inventory aligned with application registrations" do
    missing_from_inventory = registered_app_controllers - inventory_app_controllers
    stale_inventory_entries = inventory_app_controllers - registered_app_controllers

    expect(missing_from_inventory).to be_empty, "inventory is missing app controllers: #{missing_from_inventory.join(', ')}"
    expect(stale_inventory_entries).to be_empty, "inventory has stale app controllers: #{stale_inventory_entries.join(', ')}"
  end

  it "keeps gem controllers outside the App side controller table" do
    expect(inventory_app_controllers & GEM_CONTROLLER_IDENTIFIERS).to be_empty
    GEM_CONTROLLER_IDENTIFIERS.each do |identifier|
      expect(entrypoint_source).to match(/application\.register\("#{Regexp.escape(identifier)}",/)
      expect(inventory_source).to include(%(`#{identifier}`))
    end
  end

  it "keeps retired bridge and direct DOM setup out of the entrypoint" do
    aggregate_failures do
      expect(registered_controller_names(entrypoint_source)).not_to include("preview-tools")
      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end
end
