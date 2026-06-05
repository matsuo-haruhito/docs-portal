require "rails_helper"

RSpec.describe "Admin route identifier contract", type: :routing do
  ADMIN_MEMBER_ID_ROUTE_ALLOWLIST = [
    %r{\A/admin/model_browser/:model_key},
    %r{\A/admin/api_specification/site/\(\*site_path\)}
  ].freeze

  def admin_route_paths_with_id_param
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/admin/")
      next unless path.match?(%r{/:id(?:[/.]|\()})
      next if ADMIN_MEMBER_ID_ROUTE_ALLOWLIST.any? { |pattern| path.match?(pattern) }

      path
    end
  end

  it "does not expose admin member routes with the default id parameter" do
    expect(admin_route_paths_with_id_param).to be_empty
  end

  it "recognizes project member routes with code instead of id" do
    expect(get: "/admin/projects/OPS-001/edit").to route_to("admin/projects#edit", code: "OPS-001")
    expect(patch: "/admin/projects/OPS-001").to route_to("admin/projects#update", code: "OPS-001")
    expect(get: "/admin/projects/OPS-001/external_preview").to route_to("admin/project_external_previews#show", code: "OPS-001")
    expect(post: "/admin/projects/OPS-001/apply_template").to route_to("admin/project_templates#create", code: "OPS-001")
  end

  it "recognizes representative admin member routes with public_id instead of id" do
    expect(get: "/admin/companies/company-public/edit").to route_to("admin/companies#edit", public_id: "company-public")
    expect(patch: "/admin/users/user-public").to route_to("admin/users#update", public_id: "user-public")
    expect(get: "/admin/generated_file_events/event-public").to route_to("admin/generated_file_events#show", public_id: "event-public")
    expect(post: "/admin/generated_file_events/event-public/retry_dispatch").to route_to("admin/generated_file_events#retry_dispatch", public_id: "event-public")
    expect(patch: "/admin/documents/document-public/archive").to route_to("admin/documents#archive", public_id: "document-public")
    expect(post: "/admin/external_folder_sync_sources/source-public/recheck_metadata").to route_to("admin/external_folder_sync_sources#recheck_metadata", public_id: "source-public")
    expect(patch: "/admin/access_requests/request-public").to route_to("admin/access_requests#update", public_id: "request-public")
  end
end
