require "rails_helper"

RSpec.describe "admin member route params", type: :routing do
  def route_path_for(route_name)
    route = Rails.application.routes.routes.find { |candidate| candidate.name == route_name }

    expect(route).to be_present, "Expected route #{route_name.inspect} to exist"
    route.path.spec.to_s
  end

  it "keeps admin member resources on public_id params" do
    route_names = %w[
      edit_admin_company admin_company
      edit_admin_user admin_user
      edit_admin_project_membership admin_project_membership
      edit_admin_consent_term admin_consent_term
      edit_admin_project_consent_setting admin_project_consent_setting
      edit_admin_git_import_source admin_git_import_source
      admin_generated_file_event retry_dispatch_admin_generated_file_event
      admin_generated_file_run retry_run_admin_generated_file_run
      admin_zip_import admin_file_upload_dry_run
      edit_admin_microsoft_graph_connection admin_microsoft_graph_connection
      admin_recurring_job_schedule request_run_admin_recurring_job_schedule
      edit_admin_external_folder_sync_source admin_external_folder_sync_source dry_run_admin_external_folder_sync_source
      edit_admin_document admin_document archive_admin_document
      admin_bulk_edit_dry_run
      edit_admin_document_set admin_document_set
      edit_admin_document_permission admin_document_permission
      edit_admin_webhook_endpoint admin_webhook_endpoint
      admin_webhook_delivery retry_dispatch_admin_webhook_delivery
      admin_access_request
    ]

    route_names.each do |route_name|
      expect(route_path_for(route_name)).to include(":public_id"), "#{route_name} should use :public_id"
    end
  end

  it "keeps admin project member resources on code params" do
    route_names = %w[
      edit_admin_project admin_project
      external_preview_admin_project permission_preview_admin_project apply_template_admin_project
    ]

    route_names.each do |route_name|
      expect(route_path_for(route_name)).to include(":code"), "#{route_name} should use :code"
    end
  end

  it "does not add default numeric id params to admin routes" do
    offending_routes = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s
      next unless path.start_with?("/admin/") && path.include?("/:id")

      "#{route.name || "(unnamed)"} #{path}"
    end

    expect(offending_routes).to be_empty, <<~MESSAGE.squish
      Admin member routes should use explicit public identifiers such as :public_id or :code.
      Index-only, collection-only, wildcard, and non-resource routes are outside this guard.
      Offending routes: #{offending_routes.join(", ")}
    MESSAGE
  end

  it "keeps collection-only and wildcard admin routes outside the member id guard" do
    collection_route_names = %w[
      admin_access_logs
      admin_document_usage_reports
      admin_read_confirmations
      admin_git_import_runs
    ]

    collection_route_names.each do |route_name|
      expect(route_path_for(route_name)).not_to match(%r{/:\w+}), "#{route_name} should remain collection-only"
    end

    expect(route_path_for("admin_model_browser_model")).to include(":model_key")
    expect(route_path_for("site_admin_api_specification")).to include("*site_path")
  end
end
