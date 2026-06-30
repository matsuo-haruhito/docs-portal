require "rails_helper"

RSpec.describe "admin/document_sets fixed version selector source" do
  let(:document_set_form) do
    Rails.root.join("app/views/admin/document_sets/_form.html.slim").read
  end

  let(:document_sets_helper) do
    Rails.root.join("app/helpers/admin/document_sets_helper.rb").read
  end

  let(:application_entrypoint) do
    Rails.root.join("app/frontend/entrypoints/application.js").read
  end

  let(:document_filter_controller) do
    Rails.root.join("app/frontend/controllers/document_set_document_filter_controller.js").read
  end

  it "keeps the fixed version selector param shape and delegates option and rails fields kit wiring to helpers" do
    aggregate_failures do
      expect(document_set_form).to include('select_tag("document_set_items[#{index}][document_version_id]"')
      expect(document_set_form).to include("options_for_select(document_set_version_options(item), item&.document_version_id)")
      expect(document_set_form).to include("document_set_version_select_html_options(document)")
      expect(document_set_form).not_to include('["最新版を使う", ""] + document.document_versions')
      expect(document_set_form).not_to include('data: { controller: "rails-fields-kit--tom-select"')
    end
  end

  it "defines bounded option restoration and rails fields kit select wiring in the document sets helper" do
    aggregate_failures do
      expect(document_sets_helper).to include("def document_set_version_options(item)")
      expect(document_sets_helper).to include('options = [["最新版を使う", ""]]')
      expect(document_sets_helper).to include("document_set_fixed_version_option_label(selected_version)")
      expect(document_sets_helper).to include("def document_set_version_select_html_options(document")
      expect(document_sets_helper).to include('controller: "rails-fields-kit--tom-select"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_kind_value: "select"')
      expect(document_sets_helper).to include("document_version_search_admin_document_sets_path(project_id: document.project_id, document_id: document.id)")
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_query_param_value: "q"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_value_field_value: "id"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_label_field_value: "text"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_placeholder_value: placeholder')
      expect(document_sets_helper).to include("rails_fields_kit__tom_select_max_options_value: Admin::DocumentSetsController::DOCUMENT_VERSION_SEARCH_LIMIT")
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_plugins_value: ["clear_button"]')
    end
  end

  it "keeps the document table param shape while adding a progressive filter" do
    aggregate_failures do
      expect(document_set_form).to include('data-controller="document-set-document-filter"')
      expect(document_set_form).to include('data-action="input->document-set-document-filter#filter"')
      expect(document_set_form).to include('data-document-set-document-filter-target="row"')
      expect(document_set_form).to include('data-document-set-document-filter-search-text="#{document.title} #{document.slug}"')
      expect(document_set_form).to include('hidden_field_tag "document_set_items[#{index}][document_id]"')
      expect(document_set_form).to include('check_box_tag "document_set_items[#{index}][selected]"')
      expect(document_set_form).to include('number_field_tag "document_set_items[#{index}][sort_order]"')
      expect(document_set_form).to include('text_field_tag "document_set_items[#{index}][note]"')
      expect(document_set_form).not_to include("remote: true")
    end
  end

  it "registers a local row filter without changing the fixed version selector wiring" do
    aggregate_failures do
      expect(application_entrypoint).to include('import "./document_set_document_filter.css"')
      expect(application_entrypoint).to include('import DocumentSetDocumentFilterController from "../controllers/document_set_document_filter_controller"')
      expect(application_entrypoint).to include('application.register("document-set-document-filter", DocumentSetDocumentFilterController)')
      expect(document_filter_controller).to include('static targets = ["query", "row", "status", "checkbox", "selectedOnly", "empty", "tableBody"]')
      expect(document_filter_controller).to include("row.hidden = !visible")
      expect(document_filter_controller).not_to include("fetch(")
    end
  end
end
