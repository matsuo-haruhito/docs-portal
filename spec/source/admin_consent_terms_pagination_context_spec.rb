# frozen_string_literal: true

RSpec.describe "admin consent terms pagination context" do
  let(:view_source) { Rails.root.join("app/views/admin/consent_terms/index.html.slim").read }

  it "keeps consent term pagination links labeled with list context and destination page" do
    expect(view_source).to include("previous_consent_term_page = @consent_terms_page - 1")
    expect(view_source).to include('previous_consent_term_page_label = "同意文面一覧の#{previous_consent_term_page}ページ目へ（現在の検索条件を保持）"')
    expect(view_source).to include("admin_consent_terms_path(consent_term_pagination_params.merge(page: previous_consent_term_page))")
    expect(view_source).to include("aria: { label: previous_consent_term_page_label }, title: previous_consent_term_page_label")

    expect(view_source).to include("next_consent_term_page = @consent_terms_page + 1")
    expect(view_source).to include('next_consent_term_page_label = "同意文面一覧の#{next_consent_term_page}ページ目へ（現在の検索条件を保持）"')
    expect(view_source).to include("admin_consent_terms_path(consent_term_pagination_params.merge(page: next_consent_term_page))")
    expect(view_source).to include("aria: { label: next_consent_term_page_label }, title: next_consent_term_page_label")
  end

  it "keeps current consent term filters and per-page setting in pagination params" do
    expect(view_source).to include("consent_term_filter_link_params = @consent_term_filters.select { |_key, value| value.present? }")
    expect(view_source).to include("consent_term_pagination_params = consent_term_filter_link_params.merge(per_page: @consent_terms_per_page)")
    expect(view_source).to include("nav.pagination aria-label=\"同意文面一覧ページ移動\"")
    expect(view_source).to include("= link_to \"前へ\"")
    expect(view_source).to include("= link_to \"次へ\"")
  end
end
