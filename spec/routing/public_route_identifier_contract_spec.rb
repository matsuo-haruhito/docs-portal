require "rails_helper"

RSpec.describe "Public route identifier contract", type: :routing do
  PUBLIC_ID_CONTROLLERS = %w[
    access_requests
    consents
    document_approval_requests
    document_bookmarks
    document_versions
    read_confirmations
  ].freeze

  CONTEXT_ONLY_CONTROLLERS = %w[
    document_uploads
    project_ai_contexts
    project_document_zips
    projects
  ].freeze

  EXPECTED_DYNAMIC_SEGMENTS_BY_CONTROLLER = PUBLIC_ID_CONTROLLERS.to_h { |controller| [controller, [:public_id]] }.merge(
    CONTEXT_ONLY_CONTROLLERS.to_h { |controller| [controller, [:project_code]] }
  ).merge(
    "document_catalogs" => [:project_code, :public_id],
    "document_delivery_logs" => [:document_set_public_id, :document_slug, :project_code, :public_id],
    "document_file_archive_entries" => [:document_file_public_id],
    "document_files" => [:asset_path, :public_id],
    "document_review_comments" => [:document_slug, :document_version_public_id, :project_code, :public_id],
    "document_sets" => [:project_code, :public_id],
    "document_sites" => [:document_version_public_id, :site_path],
    "document_version_archives" => [:document_version_public_id],
    "document_version_quality_checks" => [:document_version_public_id],
    "document_version_rollbacks" => [:document_version_public_id],
    "document_version_upload_reviews" => [:document_version_public_id],
    "document_views" => [:document_version_public_id],
    "documents" => [:project_code, :slug],
    "project_sites" => [:project_code, :site_path]
  ).freeze

  COLLECTION_ONLY_CONTROLLERS = %w[
    accessible_documents
    dashboard
    external_folder_sync_webhooks
    sessions
  ].freeze

  WILDCARD_SEGMENTS = %i[asset_path site_path].freeze
  CONTEXT_SEGMENTS = %i[
    document_file_public_id
    document_set_public_id
    document_slug
    document_version_public_id
    project_code
  ].freeze
  MEMBER_IDENTIFIER_SEGMENTS = %i[public_id slug].freeze

  def public_routes
    Rails.application.routes.routes.select do |route|
      path = route.path.spec.to_s
      controller = route.defaults[:controller]

      controller.present? &&
        !path.start_with?("/admin") &&
        !path.start_with?("/api/internal") &&
        !path.start_with?("/rails_table_preferences")
    end
  end

  def dynamic_segments_for(route)
    route.path.spec.to_s.scan(/[:*]([a-z_]+)/).flatten.map(&:to_sym) - [:format]
  end

  def dynamic_segments_by_controller
    public_routes.each_with_object({}) do |route, segments_by_controller|
      segments = dynamic_segments_for(route)
      next if segments.empty?

      controller = route.defaults.fetch(:controller)
      segments_by_controller[controller] ||= []
      segments_by_controller[controller] |= segments
    end.transform_values(&:sort)
  end

  it "keeps every public dynamic route identifier intentionally classified" do
    expect(dynamic_segments_by_controller).to eq(EXPECTED_DYNAMIC_SEGMENTS_BY_CONTROLLER.transform_values(&:sort))
  end

  it "uses public_id for top-level user-facing member resources" do
    PUBLIC_ID_CONTROLLERS.each do |controller|
      expect(dynamic_segments_by_controller.fetch(controller)).to eq([:public_id])
    end
  end

  it "uses code and slug for project and project document routes" do
    expect(dynamic_segments_by_controller.fetch("projects")).to eq([:project_code])
    expect(dynamic_segments_by_controller.fetch("documents")).to eq([:project_code, :slug])
  end

  it "keeps wildcard and parent context segments separate from member identifiers" do
    classified_segments = dynamic_segments_by_controller.values.flatten.uniq

    expect(classified_segments).to include(*WILDCARD_SEGMENTS)
    expect(classified_segments).to include(*CONTEXT_SEGMENTS)
    expect(classified_segments).to include(*MEMBER_IDENTIFIER_SEGMENTS)
    expect(classified_segments).not_to include(:id)
  end

  it "keeps collection-only public controllers out of the member identifier guard" do
    COLLECTION_ONLY_CONTROLLERS.each do |controller|
      matching_routes = public_routes.select { |route| route.defaults[:controller] == controller }

      expect(matching_routes).not_to be_empty
      expect(matching_routes.flat_map { |route| dynamic_segments_for(route) }).to be_empty
    end
  end
end
