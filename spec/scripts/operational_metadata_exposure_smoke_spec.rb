# frozen_string_literal: true

require "spec_helper"

RSpec.describe "bin/operational_metadata_exposure_smoke" do
  let(:script_path) { File.expand_path("../../bin/operational_metadata_exposure_smoke", __dir__) }
  let(:script) { File.read(script_path) }

  it "runs the planned operational metadata request spec subset" do
    expected_specs = [
      "spec/requests/admin_file_upload_dry_runs_spec.rb",
      "spec/requests/admin_missing_document_files_spec.rb",
      "spec/requests/admin_webhook_deliveries_spec.rb",
      "spec/requests/admin_external_folder_sync_sources_spec.rb",
      "spec/requests/admin_microsoft_graph_connections_spec.rb"
    ]

    expected_specs.each do |spec_file|
      expect(script).to include(%("#{spec_file}"))
    end
    expect(script).to include("Missing operational metadata exposure smoke specs")
    expect(script).to include('exec "bundle", "exec", "rspec", *SPEC_FILES, *ARGV')
  end
end
