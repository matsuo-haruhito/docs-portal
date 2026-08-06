require "rails_helper"

RSpec.describe "Admin git import source directory options", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before { sign_in_as(admin_user) }

  describe "GET /admin/git_import_sources/directory_search" do
    it "returns directory options when installation_id, repository, and branch are present" do
      directories = %w[docs docs/source lib src]
      fake_result = GitHubAppDirectoryOptions::Result.new(directories:, fallback: false, message: nil)
      allow(GitHubAppDirectoryOptions).to receive(:new).and_return(instance_double(GitHubAppDirectoryOptions, call: fake_result))

      get directory_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345", repository: "org/repo", branch: "main" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(false)
      expect(json["options"].map { |o| o["value"] }).to eq(%w[docs docs/source lib src])
    end

    it "returns fallback when repository is missing" do
      get directory_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345", branch: "main" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
      expect(json["options"]).to eq([])
      expect(json["message"]).to include("手入力")
    end

    it "returns fallback when branch is missing" do
      get directory_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345", repository: "org/repo" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
      expect(json["options"]).to eq([])
    end

    it "returns fallback when installation_id is missing" do
      get directory_search_admin_git_import_sources_path(format: :json),
        params: { repository: "org/repo", branch: "main" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
      expect(json["options"]).to eq([])
    end

    it "returns fallback when API raises an error" do
      allow(GitHubAppDirectoryOptions).to receive(:new).and_return(
        instance_double(GitHubAppDirectoryOptions, call: GitHubAppDirectoryOptions::Result.new(
          directories: [], fallback: true, message: GitHubAppDirectoryOptions::FALLBACK_MESSAGE
        ))
      )

      get directory_search_admin_git_import_sources_path(format: :json),
        params: { installation_id: "12345", repository: "org/repo", branch: "main" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["fallback"]).to eq(true)
      expect(json["message"]).to include("手入力")
    end
  end
end
