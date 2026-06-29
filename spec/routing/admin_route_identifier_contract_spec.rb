require "rails_helper"

RSpec.describe "Admin route identifier contract", type: :routing do
  # When adding or changing admin member routes, classify the controller in
  # exactly one group below before updating docs. Most admin member resources
  # should use public_id; project-owned member routes use code; collection-only
  # controllers must stay dynamic-segment free. A new numeric :id segment should
  # fail this spec first and be handled as a concrete route-contract issue.
  PUBLIC_ID_CONTROLLERS = %w[
    admin/access_requests
    admin/bulk_edit_dry_runs
    admin/companies
    admin/consent_terms
    admin/document_catalogs
    admin/document_permissions
    admin/document_sets
    admin/documents
    admin/external_folder_sync_sources
    admin/file_upload_dry_runs
    admin/generated_file_events
    admin/generated_file_runs
    admin/git_import_sources
    admin/microsoft_graph_connections
    admin/project_consent_settings
    admin/project_memberships
    admin/recurring_job_schedules
    admin/users
    admin/webhook_deliveries
    admin/webhook_endpoints
    admin/zip_imports
  ].freeze

  CODE_CONTROLLERS = %w[
    admin/project_external_previews
    admin/project_permission_previews
    admin/project_templates
    admin/projects
  ].freeze

  COLLECTION_ONLY_CONTROLLERS = %w[
    admin/access_logs
    admin/document_usage_reports
    admin/git_import_runs
    admin/read_confirmations
  ].freeze

  EXPECTED_DYNAMIC_SEGMENTS_BY_CONTROLLER = PUBLIC_ID_CONTROLLERS.to_h { |controller| [controller, [:public_id]] }.merge(
    CODE_CONTROLLERS.to_h { |controller| [controller, [:code]] }
  ).merge(
    "admin/api_specifications" => [:site_path],
    "admin/external_folder_sync_oauth_connections" => [:external_folder_sync_source_public_id],
    "admin/model_browsers" => [:model_key]
  ).freeze

  def admin_routes
    Rails.application.routes.routes.select do |route|
      route.path.spec.to_s.start_with?("/admin") && route.defaults[:controller]&.start_with?("admin/")
    end
  end

  def dynamic_segments_for(route)
    route.path.spec.to_s.scan(/[:*]([a-z_]+)/).flatten.map(&:to_sym) - [:format]
  end

  def dynamic_segments_by_controller
    admin_routes.each_with_object({}) do |route, segments_by_controller|
      segments = dynamic_segments_for(route)
      next if segments.empty?

      controller = route.defaults.fetch(:controller)
      segments_by_controller[controller] ||= []
      segments_by_controller[controller] |= segments
    end
  end

  it "keeps every admin dynamic route identifier intentionally classified" do
    expect(dynamic_segments_by_controller).to eq(EXPECTED_DYNAMIC_SEGMENTS_BY_CONTROLLER)
  end

  it "uses public_id for major admin member resources" do
    PUBLIC_ID_CONTROLLERS.each do |controller|
      expect(dynamic_segments_by_controller.fetch(controller)).to eq([:public_id])
    end
  end

  it "uses code for admin project member routes and project member actions" do
    CODE_CONTROLLERS.each do |controller|
      expect(dynamic_segments_by_controller.fetch(controller)).to eq([:code])
    end
  end

  it "keeps collection-only admin resources out of the member identifier guard" do
    COLLECTION_ONLY_CONTROLLERS.each do |controller|
      matching_routes = admin_routes.select { |route| route.defaults[:controller] == controller }

      expect(matching_routes).not_to be_empty
      expect(matching_routes.flat_map { |route| dynamic_segments_for(route) }).to be_empty
    end
  end
end
