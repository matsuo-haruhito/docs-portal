# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Nav dropdown behavior smoke" do
  it "runs the Node behavior smoke for one-open, outside-click, and Escape focus" do
    stdout, stderr, status = Open3.capture3(
      "node",
      "--test",
      Rails.root.join("spec/frontend/nav_dropdowns_behavior.test.mjs").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
