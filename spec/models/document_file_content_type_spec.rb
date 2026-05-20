require "rails_helper"

RSpec.describe DocumentFile, type: :model do
  describe "#effective_content_type" do
    it "treats mdx files as text markdown" do
      file = described_class.new(file_name: "docs/guide.mdx", content_type: "application/octet-stream")

      expect(file.effective_content_type).to eq("text/markdown; charset=utf-8")
    end
  end
end
