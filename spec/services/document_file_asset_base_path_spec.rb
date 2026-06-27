require "rails_helper"

RSpec.describe DocumentFileAssetBasePath do
  let(:file) { instance_double(DocumentFile) }

  def build_path(current_tree_path)
    described_class.new(
      file:,
      current_tree_path:,
      path_builder: ->(_file, asset_path:) { "/files/asset/#{asset_path}" }
    ).call
  end

  it "uses current directory for nested files" do
    expect(build_path("docs/guide/index.html")).to eq("/files/asset/docs/guide")
  end

  it "uses the asset file directory when an embedded HTML asset is nested differently from the owner" do
    expect(build_path("docs/assets/detail/page.html")).to eq("/files/asset/docs/assets/detail")
  end

  it "uses root asset path for top-level files" do
    expect(build_path("index.html")).to eq("/files/asset")
  end

  it "normalizes blank current path to root asset path" do
    expect(build_path(nil)).to eq("/files/asset")
  end
end
