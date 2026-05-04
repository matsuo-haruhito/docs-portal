require "rails_helper"

RSpec.describe ProjectDocumentTemplate do
  it "loads the standard project template" do
    template = described_class.load("standard_project")

    expect(template.name).to eq("standard_project")
    expect(template.documents).not_to be_empty
    expect(template.documents.first.source_path).to eq("01_要件定義/README.md")
    expect(template.documents.first.title).to eq("要件定義 README")
    expect(template.documents.first.slug).to eq("01-readme-md")
  end

  it "raises for missing templates" do
    expect { described_class.load("missing") }.to raise_error(ArgumentError, /template not found/)
  end
end
