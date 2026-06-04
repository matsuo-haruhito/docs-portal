require "rails_helper"

RSpec.describe Admin::ExternalFolderSyncSourcesHelper, type: :helper do
  describe "#external_folder_sync_latest_error_preview" do
    it "returns a placeholder for blank messages" do
      expect(helper.external_folder_sync_latest_error_preview(nil)).to eq("-")
      expect(helper.external_folder_sync_latest_error_preview("  ")).to eq("-")
    end

    it "masks sensitive key-value fragments and private-looking paths" do
      message = "Google Drive failed Authorization: Bearer abc123 token=raw-token secret=raw-secret path C:/Users/alice/customer-docs/policies/secret.pdf"

      preview = helper.external_folder_sync_latest_error_preview(message)

      expect(preview).to include("Authorization: [masked]")
      expect(preview).to include("token=[masked]")
      expect(preview).to include("secret=[masked]")
      expect(preview).to include("[path hidden]")
      expect(preview).not_to include("Bearer abc123")
      expect(preview).not_to include("raw-token")
      expect(preview).not_to include("raw-secret")
      expect(preview).not_to include("C:/Users/alice/customer-docs/policies/secret.pdf")
      expect(preview).not_to include("customer-docs")
    end

    it "masks sensitive URL query values" do
      preview = helper.external_folder_sync_latest_error_preview("Fetch failed https://graph.example.test/sync?access_token=abc123&folder=Shared")

      expect(preview).to include("access_token=[masked]")
      expect(preview).not_to include("access_token=abc123")
    end

    it "keeps list previews short" do
      message = "Error " + ("long-message " * 20)

      preview = helper.external_folder_sync_latest_error_preview(message)

      expect(preview.length).to be <= 123
      expect(preview).to end_with("...")
    end
  end
end
