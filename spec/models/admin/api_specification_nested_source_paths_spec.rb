require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Admin API specification nested source paths" do
  let(:nested_dir) { Rails.root.join("docs-src", "tmp-api-source-paths-#{SecureRandom.hex(4)}") }
  let(:nested_source_path) { nested_dir.join("nested.md") }

  after do
    FileUtils.rm_rf(nested_dir)
  end

  it "includes nested docs-src markdown files" do
    FileUtils.mkdir_p(nested_dir)
    File.write(nested_source_path, "# Nested API doc\n")

    page = Admin::ApiSpecificationPage.new

    expect(page.source_paths).to include(nested_source_path)
  end
end
