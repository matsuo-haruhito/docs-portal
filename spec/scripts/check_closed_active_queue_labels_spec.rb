# frozen_string_literal: true

require "spec_helper"
require "stringio"
require_relative "../../.github/scripts/check_closed_active_queue_labels"

RSpec.describe ClosedActiveQueueLabels do
  def item(number:, state:, labels:, pull_request: false, state_reason: nil)
    {
      "number" => number,
      "state" => state,
      "state_reason" => state_reason,
      "labels" => labels.map { |name| { "name" => name } },
      "html_url" => "https://github.example.test/repo/issues/#{number}"
    }.tap do |payload|
      payload["pull_request"] = { "url" => "https://api.github.example.test/pulls/#{number}" } if pull_request
    end
  end

  it "reports closed issues and pull requests that still have active queue labels" do
    entries = described_class.drift_entries([
      item(number: 12, state: "closed", state_reason: "completed", labels: ["status:ready-for-agent", "track:quality"]),
      item(number: 13, state: "closed", labels: ["agent:needs-review", "area:devops"], pull_request: true)
    ])

    expect(entries).to contain_exactly(
      include(number: 12, kind: "issue", state: "closed", state_reason: "completed", labels: ["status:ready-for-agent"]),
      include(number: 13, kind: "pull_request", state: "closed", state_reason: nil, labels: ["agent:needs-review"])
    )
  end

  it "ignores closed items that only keep historical labels" do
    entries = described_class.drift_entries([
      item(number: 21, state: "closed", labels: ["area:test", "track:quality", "risk:low", "type:test", "scope:maintenance"])
    ])

    expect(entries).to be_empty
  end

  it "ignores open items even when they have active queue labels" do
    entries = described_class.drift_entries([
      item(number: 31, state: "open", labels: ["status:ready-for-agent", "agent:planned"])
    ])

    expect(entries).to be_empty
  end

  it "returns a safe error when the GitHub token is missing" do
    stdout = StringIO.new
    stderr = StringIO.new

    status = described_class.run(argv: ["--repo", "owner/repo"], env: {}, out: stdout, err: stderr)

    expect(status).to eq(2)
    expect(stdout.string).to be_empty
    expect(stderr.string).to include("GITHUB_TOKEN is required")
  end

  it "formats a short report with item number, kind, state, and active labels" do
    report = described_class.format_report([
      {
        number: 44,
        kind: "issue",
        state: "closed",
        state_reason: "completed",
        labels: ["status:needs-human", "agent:needs-review"],
        url: "https://github.example.test/repo/issues/44"
      }
    ])

    expect(report).to include("#44 issue state=closed, reason=completed")
    expect(report).to include("labels=status:needs-human, agent:needs-review")
  end
end
