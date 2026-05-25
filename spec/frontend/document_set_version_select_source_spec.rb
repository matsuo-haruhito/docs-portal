require "rails_helper"

RSpec.describe "admin/document_sets fixed version selector source" do
  let(:source) { Rails.root.join("app/views/admin/document_sets/_form.html.slim").read }

  it "keeps the nested parameter name while enabling rails fields kit tom select" do
    aggregate_failures do
      expect(source).to include('"document_set_items[#{index}][document_version_id]"')
      expect(source).to include('controller: "rails-fields-kit--tom-select"')
      expect(source).to include('rails_fields_kit__tom_select_kind_value: "select"')
      expect(source).to include('rails_fields_kit__tom_select_placeholder_value: "固定する版を検索"')
      expect(source).to include('rails_fields_kit__tom_select_plugins_value: ["clear_button"]')
    end
  end

  it "keeps the latest-version fallback option available" do
    expect(source).to include('["最新版を使う", ""]')
  end
end
