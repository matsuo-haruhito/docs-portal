require "rails_helper"

RSpec.describe "route identifier contract", type: :routing do
  def member_segment_contract(label, prefix, expected_segment)
    escaped_prefix = Regexp.escape(prefix)

    {
      label:,
      pattern: %r{\A#{escaped_prefix}/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment:
    }
  end

  def nested_project_contract(label, resource_path, expected_segment)
    {
      label:,
      pattern: %r{\A/projects/:[a-z_]+/#{resource_path}/:(?<segment>[a-z_]+)(?:[/.]|\z)},
      expected_segment:
    }
  end

  def route_identifier_contracts
    [
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
      nested_project_contract("project documents", "documents", "slug"),
      nested_project_contract("project document sets", "document_sets", "public_id"),
      nested_project_contract("project document catalogs", "document_catalogs", "public_id"),
      member_segment_contract("document versions", "/document_versions", "public_id"),
      member_segment_contract("document files", "/document_files", "public_id")
    ]
  end

  def route_paths
    Rails.application.routes.routes.filter_map do |route|
      route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
    end.uniq
  end

  it "keeps major admin and public member routes on their documented identifiers" do
    failures = route_identifier_contracts.flat_map do |contract|
      matching_paths = route_paths.select { |path| path.match?(contract[:pattern]) }

      if matching_paths.empty?
        next ["#{contract[:label]}: no member route matched #{contract[:pattern].inspect}"]
      end

      matching_paths.filter_map do |path|
        segment = path.match(contract[:pattern])[:segment]
        next if segment == contract[:expected_segment]

        "#{contract[:label]}: #{path} uses :#{segment}, expected :#{contract[:expected_segment]}"
      end
    end

    expect(failures).to be_empty,
      "URL identifier drift detected:\n#{failures.join("\n")}"
  end
end
