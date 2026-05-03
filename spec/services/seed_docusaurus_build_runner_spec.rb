require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_build_runner")

RSpec.describe SeedSupport::DocusaurusBuildRunner do
  let(:project) { create(:project, code: "RUN#{SecureRandom.hex(3)}") }
  let(:document) { create(:document, project:, title: "Runner Doc", slug: "runner-doc") }
  let(:version) { create(:document_version, document:, site_build_path: "docs/runner-doc") }
  let(:workspace) { Rails.root.join("tmp", "build-runner-#{SecureRandom.hex(4)}") }
  let(:docs_src) { workspace.join("docs-src") }
  let(:build_output_dir) { workspace.join("build") }

  before do
    FileUtils.mkdir_p(build_output_dir.join("docs", "runner-doc"))
    File.write(build_output_dir.join("docs", "runner-doc", "index.html"), "<html>ok</html>")
  end

  after do
    FileUtils.rm_rf(workspace)
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  it "copies build output to the version site root when npm build succeeds" do
    allow(Open3).to receive(:capture3).and_return(["", "", instance_double(Process::Status, success?: true)])

    described_class.new(
      source_dir: workspace,
      version:,
      docs_src:,
      build_output_dir:
    ).run!

    expect(version.site_entry_absolute_path).to exist
    expect(version.site_entry_absolute_path.read).to include("ok")
  end
end
