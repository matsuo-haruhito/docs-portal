require "rails_helper"

RSpec.describe "admin member route identifiers" do
  PUBLIC_ID_MEMBER_ROUTES = %i[
    admin_company
    admin_user
    admin_project_membership
    admin_consent_term
    admin_project_consent_setting
    admin_git_import_source
    admin_generated_file_event
    admin_generated_file_run
    admin_zip_import
    admin_file_upload_dry_run
    admin_microsoft_graph_connection
    admin_recurring_job_schedule
    admin_external_folder_sync_source
    admin_document
    admin_bulk_edit_dry_run
    admin_document_set
    admin_document_permission
    admin_webhook_endpoint
    admin_webhook_delivery
    admin_access_request
  ].freeze

  COLLECTION_ONLY_ROUTES = %i[
    admin_git_import_runs
    admin_access_logs
    admin_document_usage_reports
    admin_read_confirmations
  ].freeze

  let(:named_routes) { Rails.application.routes.named_routes }

  def route_path(route_name)
    route = named_routes.get(route_name)
    raise "missing named route: #{route_name}" unless route

    route.path.spec.to_s
  end

  it "keeps representative admin member routes on public_id identifiers" do
    aggregate_failures do
      PUBLIC_ID_MEMBER_ROUTES.each do |route_name|
        path = route_path(route_name)

        expect(path).to include("/:public_id")
        expect(path).not_to include("/:id")
      end
    end
  end

  it "keeps admin projects on code identifiers" do
    path = route_path(:admin_project)

    aggregate_failures do
      expect(path).to include("/:code")
      expect(path).not_to include("/:public_id")
      expect(path).not_to include("/:id")
    end
  end

  it "does not require collection-only admin routes to expose member identifiers" do
    aggregate_failures do
      COLLECTION_ONLY_ROUTES.each do |route_name|
        path = route_path(route_name)

        expect(path).not_to match(/:(public_id|code|id)\b/)
      end
    end
  end
end
