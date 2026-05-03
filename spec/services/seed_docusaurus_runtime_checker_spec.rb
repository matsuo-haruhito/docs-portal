require "rails_helper"
require Rails.root.join("db/seeds/support/docusaurus_runtime_checker")

RSpec.describe SeedSupport::DocusaurusRuntimeChecker do
  it "passes when npm is available" do
    allow(Open3).to receive(:capture3).with("npm", "--version").and_return(["10.0.0", "", instance_double(Process::Status, success?: true)])

    expect(described_class.ensure_npm!).to be(true)
  end

  it "raises a clear error when npm is missing" do
    allow(Open3).to receive(:capture3).with("npm", "--version").and_raise(Errno::ENOENT)

    expect { described_class.ensure_npm! }.to raise_error(RuntimeError, /Docusaurus build requires npm/)
  end
end
