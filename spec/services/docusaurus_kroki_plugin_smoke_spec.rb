# frozen_string_literal: true

require "rails_helper"
require "open3"

RSpec.describe "Docusaurus Kroki plugin smoke" do
  it "runs the Node smoke without a live Kroki service" do
    stdout, stderr, status = Open3.capture3(
      "node",
      "--test",
      Rails.root.join("docusaurus/plugins/remark-kroki-diagrams.smoke.test.mjs").to_s
    )

    expect(status).to be_success, -> { [stdout, stderr].reject(&:blank?).join("\n") }
  end
end
