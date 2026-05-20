require "rails_helper"

RSpec.describe DocumentVersion, type: :model do
  describe ".normalize_site_page_path" do
    it "normalizes markdown, mdx, and generated html paths" do
      expect(described_class.normalize_site_page_path("docs/guide.md")).to eq("docs/guide")
      expect(described_class.normalize_site_page_path("docs/guide.markdown")).to eq("docs/guide")
      expect(described_class.normalize_site_page_path("docs/guide.mdx")).to eq("docs/guide")
      expect(described_class.normalize_site_page_path("docs/guide/index.html")).to eq("docs/guide")
    end

    it "normalizes README and index markdown entries to their directory path" do
      expect(described_class.normalize_site_page_path("docs/README.md")).to eq("docs")
      expect(described_class.normalize_site_page_path("docs/index.mdx")).to eq("docs")
      expect(described_class.normalize_site_page_path("README.mdx")).to eq("README")
    end
  end
end
