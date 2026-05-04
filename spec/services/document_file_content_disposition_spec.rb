require "rails_helper"

RSpec.describe DocumentFileContentDisposition do
  let(:document_version) { create(:document_version) }

  it "builds an attachment header from a document file" do
    file = create(:document_file, document_version:, file_name: "操作説明.pdf")

    header = described_class.new(file).header

    expect(header).to start_with("attachment;")
    expect(header).to include("filename*=UTF-8''%E6%93%8D%E4%BD%9C%E8%AA%AC%E6%98%8E.pdf")
  end

  it "builds an inline header" do
    file = create(:document_file, document_version:, file_name: "manual.pdf")

    header = described_class.new(file, disposition: "inline").header

    expect(header).to start_with("inline;")
    expect(header).to include('filename="manual.pdf"')
  end

  it "exposes convenience methods" do
    file = create(:document_file, document_version:, file_name: "manual.pdf")
    helper = described_class.new(file)

    expect(helper.attachment_header).to start_with("attachment;")
    expect(helper.inline_header).to start_with("inline;")
  end
end
