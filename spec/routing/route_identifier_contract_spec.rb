require "rails_helper"

RSpec.describe "route identifier contract", type: :routing do
  RouteIdentifierContract = Struct.new(:label, :pattern, :expected_segment, keyword_init: true)

  def member_segment_contract(label, prefix, expected_segment)
    escaped_prefix = Regexp.escape(prefix)

    RouteIdentifierContract.new(
      label:,
      pattern: %r{\A#{escaped_prefix}/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment:
    )
  end

  ROUTE_IDENTIFIER_CONTRACTS = [
    member_segment_contract("admin companies", "/admin/companies", "public_id"),
    member_segment_contract("admin users", "/admin/users", "public_id"),
    member_segment_contract("admin projects", "/admin/projects", "code"),
    member_segment_contract("admin project memberships", "/admin/project_memberships", "public_id"),
    member_segment_contract("admin consent terms", "/admin/consent_terms", "public_id"),
    member_segment_contract("admin project consent settings", "/admin/project_consent_settings", "public_id"),
    member_segment_contract("admin git import sources", "/admin/git_import_sources", "public_id"),
    member_segment_contract("admin generated file events", "/admin/generated_file_events", "public_id"),
    member_segment_contract("admin generated file runs", "/admin/generated_file_runs", "public_id"),
    member_segment_contract("admin zip imports", "/admin/zip_imports", "public_id"),
    member_segment_contract("admin file upload dry runs", "/admin/file_upload_dry_runs", "public_id"),
    member_segment_contract("admin microsoft graph connections", "/admin/microsoft_graph_connections", "public_id"),
    member_segment_contract("admin recurring job schedules", "/admin/recurring_job_schedules", "public_id"),
    member_segment_contract("admin external folder sync sources", "/admin/external_folder_sync_sources", "public_id"),
    member_segment_contract("admin documents", "/admin/documents", "public_id"),
    member_segment_contract("admin bulk edit dry runs", "/admin/bulk_edit_dry_runs", "public_id"),
    member_segment_contract("admin document sets", "/admin/document_sets", "public_id"),
    member_segment_contract("admin document permissions", "/admin/document_permissions", "public_id"),
    member_segment_contract("admin webhook endpoints", "/admin/webhook_endpoints", "public_id"),
    member_segment_contract("admin webhook deliveries", "/admin/webhook_deliveries", "public_id"),
    member_segment_contract("admin access requests", "/admin/access_requests", "public_id"),
    member_segment_contract("public projects", "/projects", "code"),
    member_segment_contract("public document approval requests", "/document_approval_requests", "public_id"),
    member_segment_contract("public document delivery logs", "/document_delivery_logs", "public_id"),
    member_segment_contract("public document bookmarks", "/document_bookmarks", "public_id"),
    member_segment_contract("public read confirmations", "/read_confirmations", "public_id"),
    member_segment_contract("public access requests", "/access_requests", "public_id"),
    RouteIdentifierContract.new(
      label: "project documents",
      pattern: %r{\A/projects/:[a-z_]+/documents/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment: "slug"
    ),
    RouteIdentifierContract.new(
      label: "project document sets",
      pattern: %r{\A/projects/:[a-z_]+/document_sets/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment: "public_id"
    ),
    RouteIdentifierContract.new(
      label: "project document catalogs",
      pattern: %r{\A/projects/:[a-z_]+/document_catalogs/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment: "public_id"
    ),
    member_segment_contract("document versions", "/document_versions", "public_id"),
    member_segment_contract("document files", "/document_files", "public_id")
  ].freeze

  def route_paths
    Rails.application.routes.routes.filter_map do |route|
      route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
    end.uniq
  end

  ROUTE_IDENTIFIER_CONTRACTS.each do |contract|
    it "keeps #{contract.label} on #{contract.expected_segment} identifiers" do
      matching_paths = route_paths.select { |path| path.match?(contract.pattern) }

      expect(matching_paths).not_to be_empty,
        "expected #{contract.label} to expose a member route matching #{contract.pattern.inspect}"

      unexpected_paths = matching_paths.filter_map do |path|
        segment = path.match(contract.pattern)[:segment]
        next if segment == contract.expected_segment

        "#{path} uses :#{segment}, expected :#{contract.expected_segment}"
      end

      expect(unexpected_paths).to be_empty,
        "#{contract.label} URL identifier drift detected:\n#{unexpected_paths.join("\n")}"
    end
  end
end
