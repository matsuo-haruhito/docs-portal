require "open3"

RSpec.describe "document_version_tabs.js" do
  it "keeps hash routing, keyboard movement, and ARIA state covered by the node smoke test" do
    output, status = Open3.capture2e("node", "--test", "spec/javascript/document_version_tabs.test.mjs", chdir: Rails.root.to_s)

    expect(status).to be_success, output
  end
end
