require "rails_helper"

RSpec.describe Admin::ApiSpecificationPage do
  describe "#source_paths" do
    it "includes all docs-src markdown files" do
      page = described_class.new

      expect(page.source_paths).to include(Rails.root.join("docs-src", "api-specification.md"))
      expect(page.source_paths).to include(Rails.root.join("docs-src", "client-file-upload-api.md"))
    end
  end
end
