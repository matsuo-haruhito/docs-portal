require "rails_helper"

RSpec.describe "Admin member route identifier contract", type: :routing do
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

  ALLOWED_NON_RESOURCE_DYNAMIC_ROUTES = {
    ["admin/api_specifications", "site"] => [:site_path],
    ["admin/external_folder_sync_oauth_connections", "destroy"] => [:external_folder_sync_source_public_id],
    ["admin/external_folder_sync_oauth_connections", "new"] => [:external_folder_sync_source_public_id],
    ["admin/model_browsers", "show"] => [:model_key]
  }.freeze

  def admin_dynamic_routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/admin/")

      parts = route.required_parts.map(&:to_sym)
      next if parts.empty?

      {
        action: route.defaults[:action],
        controller: route.defaults[:controller],
        name: route.name,
        parts: parts,
        path: path,
        verb: route.verb
      }
    end
  end

  def routes_for(controller)
    admin_dynamic_routes.select { |route| route[:controller] == controller }
  end

  def route_summary(route)
    [
      route[:name] || "(unnamed)",
      route[:verb],
      route[:path],
      "=> #{route[:controller]}##{route[:action]}",
      "parts=#{route[:parts].join(", ")}"
    ].compact.join(" ")
  end

  def route_summaries(routes)
    routes.map { |route| "  - #{route_summary(route)}" }.join("\n")
  end

  def expected_parts_for(route)
    controller = route[:controller]
    action = route[:action]

    return [:public_id] if PUBLIC_ID_CONTROLLERS.include?(controller)
    return [:code] if CODE_CONTROLLERS.include?(controller)

    ALLOWED_NON_RESOURCE_DYNAMIC_ROUTES[[controller, action]]
  end

  it "keeps primary admin resources keyed by public_id" do
    failures = PUBLIC_ID_CONTROLLERS.filter_map do |controller|
      routes = routes_for(controller)
      parts = routes.flat_map { |route| route[:parts] }.uniq
      next if parts == [:public_id]

      <<~MESSAGE
        #{controller}: expected dynamic admin member routes to use only :public_id, found #{parts.inspect}
        #{route_summaries(routes)}
      MESSAGE
    end

    expect(failures).to be_empty, <<~MESSAGE
      Admin resources should keep public URLs on public_id. Add param: :public_id to new member resources, or document a non-public_id route in the allowlist when it is intentionally keyed differently.
      #{failures.join("\n")}
    MESSAGE
  end

  it "keeps project member routes keyed by code" do
    failures = CODE_CONTROLLERS.filter_map do |controller|
      routes = routes_for(controller)
      parts = routes.flat_map { |route| route[:parts] }.uniq
      next if parts == [:code]

      <<~MESSAGE
        #{controller}: expected project member routes to use only :code, found #{parts.inspect}
        #{route_summaries(routes)}
      MESSAGE
    end

    expect(failures).to be_empty, <<~MESSAGE
      Admin project member routes should keep public URLs on project code. Add param: :code to project-scoped member routes, or document an intentional exception in the allowlist.
      #{failures.join("\n")}
    MESSAGE
  end

  it "does not introduce unclassified dynamic admin identifiers" do
    unexpected_routes = admin_dynamic_routes.reject do |route|
      expected_parts = expected_parts_for(route)
      expected_parts && route[:parts].sort == expected_parts.sort
    end

    expect(unexpected_routes).to be_empty, <<~MESSAGE
      Dynamic admin routes must use public_id/code, or be explicitly allowlisted when they use another stable key such as model_key. Add param: :public_id / param: :code before adding a new admin member resource, or update ALLOWED_NON_RESOURCE_DYNAMIC_ROUTES with a short reason in the spec.
      #{route_summaries(unexpected_routes)}
    MESSAGE
  end
end
