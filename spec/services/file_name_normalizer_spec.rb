require "rails_helper"

RSpec.describe FileNameNormalizer do
  it "keeps Japanese file names" do
    expect(described_class.new("操作説明.pdf").call).to eq("操作説明.pdf")
  end

  it "replaces path separators" do
    expect(described_class.new("folder\\child/name.pdf").call).to eq("folder_child_name.pdf")
  end

  it "removes null bytes and control characters" do
    expect(described_class.new("bad\0\nname.txt").call).to eq("badname.txt")
  end

  it "removes trailing dots and spaces" do
    expect(described_class.new("report.pdf. ").call).to eq("report.pdf")
  end

  it "uses fallback for blank names" do
    expect(described_class.new("", fallback: "download").call).to eq("download")
  end

  it "prefixes Windows reserved names" do
    expect(described_class.new("CON.txt").call).to eq("_CON.txt")
    expect(described_class.new("nul").call).to eq("_nul")
  end
end
