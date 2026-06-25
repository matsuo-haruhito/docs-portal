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
      "spec/requests/admin_microsoft_graph_connections_spec.rb",
      "spec/requests/admin_generated_file_run_operational_metadata_exposure_spec.rb",
      "spec/requests/admin_git_import_operational_metadata_exposure_spec.rb"
    ]

    expected_specs.each do |spec_file|
      expect(script).to include(%("#{spec_file}"))
      expect(script).to include(%(spec: "#{spec_file}"))
    end
    expect(script).to include("Missing operational metadata exposure smoke specs")
    expect(script).to include('exec "bundle", "exec", "rspec", *SPEC_FILES, *rspec_args')
  end

  it "keeps markdown digest format separate from RSpec passthrough" do
    expect(script).to include('argument == "--format" && argv[index + 1] == "markdown"')
    expect(script).to include('argument == "--format=markdown"')
    expect(script).to include("Operational metadata exposure smoke digest")
    expect(script).to include("do not paste raw paths, raw payloads, token-like values")
  end
end
