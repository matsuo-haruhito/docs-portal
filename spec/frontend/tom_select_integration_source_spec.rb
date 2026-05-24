require "rails_helper"

RSpec.describe "Tom Select integration source" do
  it "registers the rails fields kit controller without calling the legacy shim" do
    entrypoint_source = Rails.root.join("app/frontend/entrypoints/application.js").read

    expect(entrypoint_source).to include('import { TomSelectController } from "rails_fields_kit"')
    expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')
    expect(entrypoint_source).not_to include("setupTomSelectFields")
  end

  it "keeps the legacy export as a no-op compatibility shim" do
    shim_source = Rails.root.join("app/frontend/lib/tom_select_fields.js").read

    expect(shim_source).to include("compatibility shim")
    expect(shim_source).to include("export function setupTomSelectFields(_root = document) {}")
    expect(shim_source).not_to include("turbo:load")
    expect(shim_source).not_to include("addEventListener")
  end
end
