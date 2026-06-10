# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Document file browser controller behavior smoke" do
  it "runs the Node behavior smoke for kind filters, search, and empty state" do
    stdout, stderr, status = Open3.capture3(
      "node",
      "--test",
      Rails.root.join("spec/frontend/document_file_browser_controller.test.mjs").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
