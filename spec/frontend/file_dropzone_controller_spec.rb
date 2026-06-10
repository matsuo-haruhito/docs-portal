# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "File dropzone controller behavior smoke" do
  it "runs the Node behavior smoke for drag lifecycle and filename display" do
    stdout, stderr, status = Open3.capture3(
      "node",
      "--test",
      Rails.root.join("spec/frontend/file_dropzone_controller.test.mjs").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
