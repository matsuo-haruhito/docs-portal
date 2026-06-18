require "rails_helper"

RSpec.describe "admin member route parameters", type: :routing do
  EXPECTED_ADMIN_MEMBER_ROUTE_PARAMS = {
    "access_requests" => "public_id",
    "bulk_edit_dry_runs" => "public_id",
    "companies" => "public_id",
    "consent_terms" => "public_id",
    "document_permissions" => "public_id",
    "document_sets" => "public_id",
    "documents" => "public_id",
    "external_folder_sync_sources" => "public_id",
    "file_upload_dry_runs" => "public_id",
    "generated_file_events" => "public_id",
    "generated_file_runs" => "public_id",
    "git_import_sources" => "public_id",
    "microsoft_graph_connections" => "public_id",
    "project_consent_settings" => "public_id",
    "project_memberships" => "public_id",
    "projects" => "code",
    "recurring_job_schedules" => "public_id",
    "users" => "public_id",
    "webhook_deliveries" => "public_id",
    "webhook_endpoints" => "public_id",
    "zip_imports" => "public_id"
  }.freeze

  DIRECT_ADMIN_MEMBER_ACTIONS = %w[
    apply
    apply_template
    archive
    dry_run
    edit
    enqueue
    external_preview
    force_apply
    permission_preview
    recheck_metadata
    request_run
    restore
    retry_dispatch
    retry_run
    subscribe
    sync
    unsubscribe
  ].freeze

  INDEX_ONLY_ADMIN_RESOURCES = %w[
    access_logs
    document_usage_reports
    git_import_runs
    read_confirmations
  ].freeze

  def admin_member_route_paths(resource)
    member_action_pattern = DIRECT_ADMIN_MEMBER_ACTIONS.map { |action| Regexp.escape(action) }.join("|")
    route_prefix = %r{\A/admin/#{Regexp.escape(resource)}/:[^/()]+(?:/(?:#{member_action_pattern}))?(?:\(\.:format\))?\z}

    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      path if path.match?(route_prefix)
    end
  end

  it "keeps admin member routes on public_id or code identifiers" do
    failures = EXPECTED_ADMIN_MEMBER_ROUTE_PARAMS.filter_map do |resource, expected_param|
      paths = admin_member_route_paths(resource)
      mismatches = paths.reject do |path|
        path.match?(%r{\A/admin/#{Regexp.escape(resource)}/:#{expected_param}(?:/|\(|\z)})
      end

      next if mismatches.empty?

      "#{resource} expected :#{expected_param}, got #{mismatches.join(", ")}"
    end

    expect(failures).to be_empty, "Admin member route parameter drift:\n#{failures.join("\n")}"
  end

  it "does not treat index-only admin resources as member-route contracts" do
    unexpected_paths = INDEX_ONLY_ADMIN_RESOURCES.flat_map { |resource| admin_member_route_paths(resource) }

    expect(unexpected_paths).to be_empty, "Index-only admin resources exposed member routes:\n#{unexpected_paths.join("\n")}"
  end
end
