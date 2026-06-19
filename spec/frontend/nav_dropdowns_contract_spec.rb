require "rails_helper"

RSpec.describe "Nav dropdown contract" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/nav_dropdowns_controller.js").read }
  let(:application_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:current_label_css) { Rails.root.join("app/frontend/entrypoints/nav_current_label.css").read }
  let(:layout_source) { Rails.root.join("app/views/layouts/application.html.slim").read }
  let(:navbar_source) { Rails.root.join("app/views/shared/_navbar.html.slim").read }
  let(:navigation_helper_source) { Rails.root.join("app/helpers/navigation_helper.rb").read }

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

  it "keeps current child labels readable from active dropdown summaries" do
    aggregate_failures do
      expect(navbar_source).to include("nav_current_child_label")
      expect(navbar_source).to include("span.nav-dropdown__current-label")
      expect(navbar_source).to include('["文書セット", admin_document_sets_path]')
      expect(navbar_source).to include('["Microsoft Graph", admin_microsoft_graph_connections_path]')
      expect(navbar_source).to include('active_nav_link_to "Git取込履歴", admin_git_import_runs_path, active: false')
      expect(navigation_helper_source).to include("def nav_current_child_label(*items)")
      expect(navigation_helper_source).to include('current_path.start_with?("#{candidate_path}/")')
    end
  end

  it "loads responsive styles for the compact current child cue" do
    aggregate_failures do
      expect(application_source).to include('import "./nav_current_label.css"')
      expect(current_label_css).to include(".nav-dropdown__current-label")
      expect(current_label_css).to include("text-overflow: ellipsis")
      expect(current_label_css).to include("@media (max-width: 720px)")
    end
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
    expect(controller_source).to include("this.closeOpenDropdowns(dropdown)")

    expect(controller_source).to include('const clickedDropdown = event.target.closest?.("[data-nav-dropdown]")')
    expect(controller_source).to include("if (clickedDropdown) return")
    expect(controller_source).to include("this.closeOpenDropdowns()")

    expect(controller_source).to include('if (event.key !== "Escape") return')
    expect(controller_source).to include("closeOpenDropdowns(exceptDropdown = null)")
    expect(controller_source).to include('this.element.querySelectorAll("[data-nav-dropdown][open]")')
  end

  it "restores focus to the closed dropdown summary only on Escape" do
    expect(controller_source).to include('const dropdownToRestoreFocus = event.target.closest?.("[data-nav-dropdown][open]") || this.openDropdowns[0]')
    expect(controller_source).to include("this.restoreDropdownSummaryFocus(dropdownToRestoreFocus)")
    expect(controller_source).to include("restoreDropdownSummaryFocus(dropdown)")
    expect(controller_source).to include('dropdown?.querySelector?.("summary.nav-dropdown__summary")')
    expect(controller_source).to include("summary?.focus?.()")
  end
end
