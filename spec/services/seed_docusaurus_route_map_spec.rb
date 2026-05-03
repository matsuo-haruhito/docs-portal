require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_route_map")

RSpec.describe SeedSupport::DocusaurusRouteMap do
  let(:site_root) { Rails.root.join("tmp", "route-map-#{SecureRandom.hex(4)}") }
  let(:site_build_path) { "external_samples/sample/current" }

  after do
    FileUtils.rm_rf(site_root)
  end

  it "maps full and generated Docusaurus doc ids to route paths" do
    FileUtils.mkdir_p(site_root.join(site_build_path, "guide"))
    File.write(
      site_root.join(site_build_path, "index.html"),
      %(<html class="docs-doc-id-external_samples/sample/current/seed-root"></html>)
    )
    File.write(
      site_root.join(site_build_path, "guide", "index.html"),
      %(<html class="docs-doc-id-external_samples/sample/current/guide/seed-guide"></html>)
    )

    route_map = described_class.new(
      site_root_absolute_path: site_root,
      site_build_path:
    ).build

    expect(route_map["external_samples/sample/current/seed-root"]).to eq(site_build_path)
    expect(route_map["seed-root"]).to eq(site_build_path)
    expect(route_map["external_samples/sample/current/guide/seed-guide"]).to eq("#{site_build_path}/guide")
    expect(route_map["seed-guide"]).to eq("#{site_build_path}/guide")
  end
end
