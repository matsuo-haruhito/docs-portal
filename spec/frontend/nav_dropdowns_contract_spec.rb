require "rails_helper"

RSpec.describe "Nav dropdown contract" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/nav_dropdowns_controller.js").read }
  let(:application_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:layout_source) { Rails.root.join("app/views/layouts/application.html.slim").read }
  let(:navbar_source) { Rails.root.join("app/views/shared/_navbar.html.slim").read }

  it "registers the nav-dropdowns controller on the application layout" do
    expect(application_source).to include('import NavDropdownsController from "../controllers/nav_dropdowns_controller"')
    expect(application_source).to include('application.register("nav-dropdowns", NavDropdownsController)')
    expect(layout_source).to include('body data-controller="nav-dropdowns')
  end

  it "keeps dropdown markup on details elements in the shared navbar" do
    expect(navbar_source.scan('details.nav-dropdown data-nav-dropdown="true"').size).to be >= 2
    expect(navbar_source).to include("summary.nav-dropdown__summary")
    expect(navbar_source).to include("文書")
    expect(navbar_source).to include("履歴照会")
  end

  it "keeps document listener registration and cleanup paired" do
    expect(controller_source).to include('document.addEventListener("toggle", this.onToggle, true)')
    expect(controller_source).to include('document.removeEventListener("toggle", this.onToggle, true)')
    expect(controller_source).to include('document.addEventListener("click", this.onClick)')
    expect(controller_source).to include('document.removeEventListener("click", this.onClick)')
    expect(controller_source).to include('document.addEventListener("keydown", this.onKeydown)')
    expect(controller_source).to include('document.removeEventListener("keydown", this.onKeydown)')
  end

  it "keeps one-open-dropdown, outside-click, and Escape contracts readable" do
    expect(controller_source).to include('const dropdown = event.target.closest?.("[data-nav-dropdown]")')
    expect(controller_source).to include("if (!dropdown || !dropdown.open) return")
    expect(controller_source).to include("this.closeOthers(dropdown)")

    expect(controller_source).to include('const clickedDropdown = event.target.closest("[data-nav-dropdown]")')
    expect(controller_source).to include("if (dropdown !== clickedDropdown) dropdown.open = false")

    expect(controller_source).to include('if (event.key !== "Escape") return')
    expect(controller_source).to include('document.querySelectorAll("[data-nav-dropdown][open]").forEach')
  end
end
