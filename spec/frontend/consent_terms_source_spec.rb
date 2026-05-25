require "rails_helper"

RSpec.describe "admin consent terms source" do
  let(:index_source) { Rails.root.join("app/views/admin/consent_terms/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/consent_terms_helper.rb").read }

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('data-rails-table-preferences-column-key="title"')
      expect(index_source).to include('data-rails-table-preferences-column-key="version_label"')
      expect(index_source).to include('data-rails-table-preferences-column-key="consent_scope"')
      expect(index_source).to include('data-rails-table-preferences-column-key="requirement_timing"')
      expect(index_source).to include('data-rails-table-preferences-column-key="status"')
      expect(index_source).to include('data-rails-table-preferences-column-key="actions"')
      expect(index_source).to include("consent_scope_label(term)")
      expect(index_source).to include("consent_requirement_timing_label(term)")
      expect(index_source).to include("consent_term_status_label(term)")
      expect(index_source).to include("span.badge = term.version_label")
    end
  end

  it "defines helper metadata for the admin table and status copy" do
    aggregate_failures do
      expect(helper_source).to include("def consent_term_table_columns")
      expect(helper_source).to include("table_preferences_column(:title")
      expect(helper_source).to include("table_preferences_column(:version_label")
      expect(helper_source).to include("table_preferences_column(:consent_scope")
      expect(helper_source).to include("table_preferences_column(:requirement_timing")
      expect(helper_source).to include("table_preferences_column(:status")
      expect(helper_source).to include("table_preferences_column(:actions")
      expect(helper_source).to include("def consent_term_status_label(term)")
      expect(helper_source).to include('term.active? ? "有効" : "無効"')
    end
  end
end
