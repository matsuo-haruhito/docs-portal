require "rails_helper"

RSpec.describe DocumentVersion, type: :model do
  describe ".source_path_metadata_for!" do
    it "extracts metadata from Japanese source paths" do
      metadata = described_class.source_path_metadata_for!("作成資料/編集正本/操作説明書.md")

      expect(metadata).to include(
        source_relative_path: "作成資料/編集正本/操作説明書.md",
        source_directory: "作成資料/編集正本",
        source_file_name: "操作説明書.md",
        source_basename: "操作説明書",
        source_extension: "md"
      )
    end

    it "normalizes backslashes in Japanese source paths" do
      metadata = described_class.source_path_metadata_for!("作成資料\\編集正本\\操作説明書.md")

      expect(metadata).to include(
        source_relative_path: "作成資料/編集正本/操作説明書.md",
        source_directory: "作成資料/編集正本",
        source_file_name: "操作説明書.md"
      )
    end
  end
end
