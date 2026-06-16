require "rails_helper"

RSpec.describe "admin route param contract", type: :routing do
  PUBLIC_ID_ADMIN_RESOURCES = %w[
    companies
    users
    project_memberships
    consent_terms
    project_consent_settings
    git_import_sources
    generated_file_events
    generated_file_runs
    zip_imports
    microsoft_graph_connections
    recurring_job_schedules
    external_folder_sync_sources
    documents
    bulk_edit_dry_runs
    document_sets
    document_permissions
    webhook_endpoints
    webhook_deliveries
    access_requests
  ].freeze

  CODE_ADMIN_RESOURCES = %w[
    projects
  ].freeze

  def admin_member_paths_for(resource)
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/admin/#{resource}/")
      next unless path.match?(%r{/admin/#{resource}/:[^/(]+})

      path
    end.uniq
  end

  def expected_public_id_route_param?(resource, path)
    path.include?("/:public_id") || path.include?("/:#{resource.singularize}_public_id")
  end

  def expected_code_route_param?(resource, path)
    path.include?("/:code") || path.include?("/:#{resource.singularize}_code")
  end

  it "keeps the primary admin member resources on public_id" do
    failures = PUBLIC_ID_ADMIN_RESOURCES.filter_map do |resource|
      member_paths = admin_member_paths_for(resource)
      unexpected_paths = member_paths.reject { |path| expected_public_id_route_param?(resource, path) }
      next if member_paths.any? && unexpected_paths.empty?

      "#{resource}: #{member_paths.presence || 'no member routes'}"
    end

    expect(failures).to be_empty
  end

  it "keeps admin projects on code" do
    failures = CODE_ADMIN_RESOURCES.filter_map do |resource|
      member_paths = admin_member_paths_for(resource)
      unexpected_paths = member_paths.reject { |path| expected_code_route_param?(resource, path) }
      next if member_paths.any? && unexpected_paths.empty?

      "#{resource}: #{member_paths.presence || 'no member routes'}"
    end

    expect(failures).to be_empty
  end

  it "keeps model browser routes out of the numeric id drift guard" do
    model_browser_paths = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      path if path.start_with?("/admin/model_browser")
    end

    expect(model_browser_paths).to include("/admin/model_browser(.:format)")
    expect(model_browser_paths).to include("/admin/model_browser/:model_key(.:format)")
    expect(model_browser_paths).not_to include(a_string_including(":id"))
  end
end
