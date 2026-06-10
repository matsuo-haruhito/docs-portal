# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Document ZIP selection controller behavior smoke" do
  it "runs the Node behavior smoke for page, matching, and explicit scope display" do
    stdout, stderr, status = Open3.capture3(
      "node",
      "--test",
      Rails.root.join("spec/frontend/document_zip_selection_controller.test.mjs").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
