require "rails_helper"

RSpec.describe Admin::GeneratedFileRunsHelper, type: :helper do
  describe "#generated_file_run_diagnostic_preview" do
    it "masks bearer tokens, secret-like assignments, and private paths" do
      preview = helper.generated_file_run_diagnostic_preview(
        "Authorization: Bearer raw-token-123 client_secret=very-secret " \
        "access_token: raw-access-token failed at /Users/alice/docs/output.md " \
        "and C:/Users/alice/AppData/Local/token.txt"
      )

      expect(preview).to include("Authorization=[FILTERED]")
      expect(preview).to include("client_secret=[FILTERED]")
      expect(preview).to include("access_token=[FILTERED]")
      expect(preview).to include("failed at [FILTERED]")
      expect(preview).to include("and [FILTERED]")
      expect(preview).not_to include("raw-token-123", "very-secret", "raw-access-token")
      expect(preview).not_to include("/Users/alice", "C:/Users/alice")
    end

    it "uses the fallback marker for blank diagnostic text" do
      expect(helper.generated_file_run_diagnostic_preview(nil)).to eq("-")
      expect(helper.generated_file_run_diagnostic_preview("   ")).to eq("-")
    end

    it "truncates long diagnostic text at the configured preview limit" do
      limit = described_class::GENERATED_FILE_RUN_DIAGNOSTIC_LIMIT
      long_message = "a" * (limit + 1)

      preview = helper.generated_file_run_diagnostic_preview(long_message)

      expect(preview.length).to eq(limit)
      expect(preview).to end_with("...")
    end
  end

  describe "#generated_file_run_metadata_preview" do
    it "masks sensitive keys and string values inside nested metadata" do
      preview = helper.generated_file_run_metadata_preview(
        {
          "authorization" => "Bearer raw-authorization-token",
          "context" => {
            "client_secret" => "raw-client-secret",
            "notes" => [
              "read from /workspace/docs-portal/tmp/generated.json",
              { "access_token" => "raw-access-token" },
              "Bearer nested-token-123"
            ]
          },
          "attempt" => 2
        }
      )

      parsed_preview = JSON.parse(preview)

      expect(parsed_preview).to eq(
        "authorization" => "[FILTERED]",
        "context" => {
          "client_secret" => "[FILTERED]",
          "notes" => [
            "read from [FILTERED]",
            { "access_token" => "[FILTERED]" },
            "Bearer [FILTERED]"
          ]
        },
        "attempt" => 2
      )
      expect(preview).not_to include(
        "raw-authorization-token",
        "raw-client-secret",
        "raw-access-token",
        "nested-token-123",
        "/workspace/docs-portal"
      )
    end

    it "renders nil metadata as an empty JSON object" do
      expect(helper.generated_file_run_metadata_preview(nil)).to eq("{}")
    end
  end
end
