require "rails_helper"

RSpec.describe "admin document set fixed version selector source" do
  let(:document_set_form) do
    Rails.root.join("app/views/admin/document_sets/_form.html.slim").read
  end

  let(:document_sets_helper) do
    Rails.root.join("app/helpers/admin/document_sets_helper.rb").read
  end

  it "keeps the fixed version selector param shape and delegates rails fields kit wiring to a helper" do
    aggregate_failures do
      expect(document_set_form).to include('select_tag("document_set_items[#{index}][document_version_id]"')
      expect(document_set_form).to include("document_set_version_select_html_options")
      expect(document_set_form).to include('["最新版を使う", ""]')
      expect(document_set_form).not_to include('data: { controller: "rails-fields-kit--tom-select"')
    end
  end

  it "defines rails fields kit select wiring for the fixed version selector in the document sets helper" do
    aggregate_failures do
      expect(document_sets_helper).to include("def document_set_version_select_html_options")
      expect(document_sets_helper).to include('controller: "rails-fields-kit--tom-select"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_kind_value: "select"')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_placeholder_value: placeholder')
      expect(document_sets_helper).to include('rails_fields_kit__tom_select_plugins_value: ["clear_button"]')
    end
  end
end
