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
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  before do
    FileUtils.mkdir_p(build_output_dir.join("docs", "runner-doc"))
    File.write(build_output_dir.join("docs", "runner-doc", "index.html"), "<html>ok</html>")
  end

  after do
    FileUtils.rm_rf(workspace)
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  it "copies build output to the version site root when npm build succeeds" do
    allow(SeedSupport::DocusaurusRuntimeChecker).to receive(:ensure_runtime!).and_return(true)
    allow(Open3).to receive(:capture3).and_return(["", "", success_status])

    described_class.new(
      source_dir: workspace,
      version:,
      docs_src:,
      build_output_dir:
    ).run!

    expect(version.site_entry_absolute_path).to exist
    expect(version.site_entry_absolute_path.read).to include("ok")
  end

  it "raises build failures with command, path, stderr, and stdout context" do
    static_dir = workspace.join("static")
    allow(SeedSupport::DocusaurusRuntimeChecker).to receive(:ensure_runtime!).and_return(true)
    allow(Open3).to receive(:capture3).and_return(["stdout detail", "stderr detail", failure_status])

    runner = described_class.new(
      source_dir: workspace,
      version:,
      docs_src:,
      build_output_dir:,
      static_dir:
    )

    expect { runner.run! }.to raise_error(RuntimeError) { |error|
      expect(error.message).to include("Docusaurus build failed")
      expect(error.message).to include("source_dir: #{workspace}")
      expect(error.message).to include("docs_path: #{docs_src}")
      expect(error.message).to include("out_dir: #{build_output_dir}")
      expect(error.message).to include("static_dir: #{static_dir}")
      expect(error.message).to include("command: npm run build -- --out-dir #{build_output_dir}")
      expect(error.message).to include("stderr:")
      expect(error.message).to include("stderr detail")
      expect(error.message).to include("stdout:")
      expect(error.message).to include("stdout detail")
    }
  end

  it "keeps stdout-only build failures readable" do
    allow(SeedSupport::DocusaurusRuntimeChecker).to receive(:ensure_runtime!).and_return(true)
    allow(Open3).to receive(:capture3).and_return(["stdout only", "", failure_status])

    runner = described_class.new(
      source_dir: workspace,
      version:,
      docs_src:,
      build_output_dir:
    )

    expect { runner.run! }.to raise_error(RuntimeError) { |error|
      expect(error.message).to include("stdout:")
      expect(error.message).to include("stdout only")
      expect(error.message).not_to include("stderr:")
      expect(error.message).not_to include("static_dir:")
    }
  end
end
