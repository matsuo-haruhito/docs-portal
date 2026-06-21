require "rails_helper"

RSpec.describe "Public route identifier contract", type: :routing do
  PROJECT_CODE_SEGMENTS = %i[code project_code].freeze
  DOCUMENT_SLUG_SEGMENTS = %i[slug document_slug].freeze
  PUBLIC_ID_SEGMENTS = %i[
    public_id
    document_set_public_id
    document_version_public_id
  ].freeze
  WILDCARD_CONTENT_PATH_SEGMENTS = %i[asset_path site_path].freeze

  EXPECTED_DYNAMIC_SEGMENTS_BY_ROLE = {
    project_code: PROJECT_CODE_SEGMENTS,
    document_slug: DOCUMENT_SLUG_SEGMENTS,
    public_id: PUBLIC_ID_SEGMENTS,
    wildcard_content_path: WILDCARD_CONTENT_PATH_SEGMENTS
  }.freeze

  DOCUMENT_SLUG_CONTROLLERS = %w[
    document_approval_requests
    document_delivery_logs
    document_review_comments
    documents
  ].freeze

  WILDCARD_CONTROLLERS = %w[
    document_files
    document_sites
    project_sites
  ].freeze

  def public_app_routes
    Rails.application.routes.routes.select do |route|
      path = route.path.spec.to_s
      controller = route.defaults[:controller]

      controller.present? &&
        !path.start_with?("/admin") &&
        !path.start_with?("/api") &&
        !path.start_with?("/rails_table_preferences")
    end
  end

  def dynamic_segments_for(route)
    route.path.spec.to_s.scan(/[:*]([a-z_]+)/).flatten.map(&:to_sym) - [:format]
  end

  def route_entries
    public_app_routes.filter_map do |route|
      segments = dynamic_segments_for(route)
      next if segments.empty?

      {
        action: route.defaults.fetch(:action),
        controller: route.defaults.fetch(:controller),
        path: route.path.spec.to_s,
        segments: segments
      }
    end
  end

  def dynamic_segments_by_role
    all_segments = route_entries.flat_map { |entry| entry.fetch(:segments) }.uniq

    EXPECTED_DYNAMIC_SEGMENTS_BY_ROLE.transform_values do |allowed_segments|
      all_segments & allowed_segments
    end
  end

  def unknown_dynamic_segments
    allowed_segments = EXPECTED_DYNAMIC_SEGMENTS_BY_ROLE.values.flatten

    route_entries.flat_map { |entry| entry.fetch(:segments) }.uniq - allowed_segments
  end

  it "keeps every public dynamic segment intentionally classified" do
    expect(dynamic_segments_by_role).to eq(EXPECTED_DYNAMIC_SEGMENTS_BY_ROLE)
    expect(unknown_dynamic_segments).to be_empty
  end

  it "keeps numeric id out of public route identifiers" do
    id_routes = route_entries.select { |entry| entry.fetch(:segments).include?(:id) }

    expect(id_routes).to be_empty
  end

  it "uses code for project entry and nested project routes" do
    code_routes = route_entries.select do |entry|
      (entry.fetch(:segments) & PROJECT_CODE_SEGMENTS).any?
    end

    expect(code_routes).not_to be_empty
    expect(code_routes.select { |entry| entry.fetch(:segments).include?(:code) }.map { |entry| entry.fetch(:controller) }.uniq).to eq(["projects"])
    expect(code_routes.select { |entry| entry.fetch(:segments).include?(:project_code) }).to all(include(path: a_string_starting_with("/projects/:project_code")))
  end

  it "keeps document slug identifiers on document routes" do
    slug_routes = route_entries.select do |entry|
      (entry.fetch(:segments) & DOCUMENT_SLUG_SEGMENTS).any?
    end

    expect(slug_routes).not_to be_empty
    expect(slug_routes.map { |entry| entry.fetch(:controller) }.uniq).to match_array(DOCUMENT_SLUG_CONTROLLERS)
    expect(slug_routes.select { |entry| entry.fetch(:segments).include?(:slug) }.map { |entry| entry.fetch(:controller) }.uniq).to eq(["documents"])
  end

  it "keeps public_id identifiers separate from content path wildcards" do
    wildcard_routes = route_entries.select do |entry|
      (entry.fetch(:segments) & WILDCARD_CONTENT_PATH_SEGMENTS).any?
    end
    public_id_routes = route_entries.select do |entry|
      (entry.fetch(:segments) & PUBLIC_ID_SEGMENTS).any?
    end

    expect(wildcard_routes).not_to be_empty
    expect(wildcard_routes.map { |entry| entry.fetch(:controller) }.uniq).to match_array(WILDCARD_CONTROLLERS)
    expect(wildcard_routes.flat_map { |entry| entry.fetch(:segments) } & WILDCARD_CONTENT_PATH_SEGMENTS).to match_array(WILDCARD_CONTENT_PATH_SEGMENTS)
    expect(public_id_routes).not_to be_empty
    expect(public_id_routes.flat_map { |entry| entry.fetch(:segments) }.uniq & PUBLIC_ID_SEGMENTS).to match_array(PUBLIC_ID_SEGMENTS)
  end
end
