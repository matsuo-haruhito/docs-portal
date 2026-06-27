require "rails_helper"

RSpec.describe DocumentFileEmbeddedAssetResolver do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }
  let(:owner_file) do
    create(:document_file,
      document_version: version,
      file_name: "docs/index.html",
      content_type: "text/html",
      storage_key: "spec/embedded-assets/docs/index.html")
  end

  def resolve(path)
    described_class.new(owner_file:, requested_asset_path: path).call
  end

  it "finds an asset by normalized tree path" do
    asset = create(:document_file,
      document_version: version,
      file_name: "docs/assets/app.css",
      content_type: "text/css",
      storage_key: "spec/embedded-assets/docs/assets/app.css")

    expect(resolve("/docs/assets/./app.css")).to eq(asset)
  end

  it "does not return assets from another document version" do
    other_version = create(:document_version, document:)
    create(:document_file,
      document_version: other_version,
      file_name: "docs/assets/app.css",
      content_type: "text/css",
      storage_key: "spec/embedded-assets/other/docs/assets/app.css")

    expect(resolve("docs/assets/app.css")).to be_nil
  end

  it "rejects traversal paths" do
    create(:document_file,
      document_version: version,
      file_name: "secret.txt",
      content_type: "text/plain",
      storage_key: "spec/embedded-assets/secret.txt")

    expect(resolve("../secret.txt")).to be_nil
  end

  it "rejects backslash traversal paths" do
    create(:document_file,
      document_version: version,
      file_name: "secret.txt",
      content_type: "text/plain",
      storage_key: "spec/embedded-assets/secret.txt")

    expect(resolve("..\\secret.txt")).to be_nil
  end

  it "rejects blank and root paths" do
    expect(resolve("")).to be_nil
    expect(resolve("/")).to be_nil
    expect(resolve(".")).to be_nil
  end
end
