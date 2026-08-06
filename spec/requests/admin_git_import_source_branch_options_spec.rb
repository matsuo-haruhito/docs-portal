require "rails_helper"

RSpec.describe "Admin git import source branch options", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before { sign_in_as(admin_user) }

  describe "GET /admin/git_import_sources/branch_search" do
    it "returns branch options when installation_id and repository are present" do
      branches = %w[main develop feature/docs]
      fake_result = GitHubAppBranchOptions::Result.new(branches:, fallback: false, message: nil)
      allow(GitHubAppBranchOptions).to receive(:new).and_return(instance_double(GitHubAppBranchOptions, call: fake_result))

      get branch_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345", repository: "org/repo" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(false)
      expect(json["options"].map { |o| o["value"] }).to eq(%w[main develop feature/docs])
    end

    it "returns fallback when repository is missing" do
      get branch_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
      expect(json["options"]).to eq([])
    end

    it "returns fallback when installation_id is missing" do
      get branch_search_admin_git_import_sources_path(format: :json),
        params: { repository: "org/repo" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
    end
  end
end
