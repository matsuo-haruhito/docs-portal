require "rails_helper"

RSpec.describe ContentDispositionFilename do
  it "builds a header for Japanese file names" do
    helper = described_class.new("操作説明.pdf")

    expect(helper.header).to include("attachment;")
    expect(helper.header).to include('filename=".pdf"')
    expect(helper.header).to include("filename*=UTF-8''%E6%93%8D%E4%BD%9C%E8%AA%AC%E6%98%8E.pdf")
  end

  it "sanitizes path separators and null bytes" do
    helper = described_class.new("folder\\unsafe/name\0.pdf")

    expect(helper.ascii_fallback).to eq("folder_unsafe_name.pdf")
    expect(helper.encoded_file_name).to eq("folder_unsafe_name.pdf")
  end

  it "supports inline disposition" do
    helper = described_class.new("manual.pdf", disposition: "inline")

    expect(helper.header).to start_with("inline;")
  end

  it "falls back to attachment for unknown disposition" do
    helper = described_class.new("manual.pdf", disposition: "evil")

    expect(helper.header).to start_with("attachment;")
  end

  it "uses download when the filename is blank" do
    helper = described_class.new("")

    expect(helper.ascii_fallback).to eq("download")
    expect(helper.encoded_file_name).to eq("download")
  end
end
