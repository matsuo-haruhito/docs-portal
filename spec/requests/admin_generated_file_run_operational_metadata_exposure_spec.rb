require "rails_helper"

RSpec.describe "Admin generated file run operational metadata exposure", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "masks secret-like metadata and diagnostic details while keeping path arrays as diagnostic previews" do
    sign_in_as(admin_user)
    run = create_run!(
      status: :failed,
      source_paths: ["docs/source-input.yml"],
      changed_files: ["docs/source-input.yml"],
      generated_paths: ["generated/output.md"],
      metadata: {
        "access_token" => "raw-access-token-3673",
        "nested" => {
          "authorization" => "Bearer raw-metadata-bearer-3673",
          "source_path" => "/home/app/private-source.yml"
        },
        "notes" => ["secret=raw-note-secret-3673", "public event id gfe_3673"]
      },
      error_message: "Authorization: Bearer raw-error-bearer-3673 failed at /Users/alice/private-input.yml with token=raw-error-token-3673"
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("入力パス", "変更ファイル", "生成パス", "メタデータ", "エラー")
    expect(response.body).to include("docs/source-input.yml", "generated/output.md")
    expect(response.body).to include("public event id gfe_3673")
    expect(response.body).to include("[FILTERED]")
    expect(response.body).not_to include("raw-access-token-3673")
    expect(response.body).not_to include("raw-metadata-bearer-3673")
    expect(response.body).not_to include("raw-note-secret-3673")
    expect(response.body).not_to include("raw-error-bearer-3673")
    expect(response.body).not_to include("raw-error-token-3673")
    expect(response.body).not_to include("/home/app/private-source.yml")
    expect(response.body).not_to include("/Users/alice/private-input.yml")
  end

  it "keeps index search as a diagnostic lookup without rendering raw operational metadata" do
    sign_in_as(admin_user)
    matched_run = create_run!(
      status: :failed,
      job_id: "metadata_search_boundary_match",
      source_paths: ["docs/source-input.yml"],
      changed_files: ["docs/source-input.yml"],
      generated_paths: ["generated/output.md"],
      metadata: {
        "operation_reference" => "metadata-search-boundary-3891",
        "access_token" => "raw-index-token-3891",
        "source_path" => "/home/app/private-index-source.yml"
      },
      error_message: "Authorization: Bearer raw-index-bearer-3891 failed at /Users/alice/private-index-input.yml"
    )
    unmatched_run = create_run!(
      status: :failed,
      job_id: "metadata_search_boundary_unmatched",
      metadata: {"operation_reference" => "other-reference"}
    )

    get admin_generated_file_runs_path(q: "metadata-search-boundary-3891")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matched_run.public_id)
    expect(response.body).not_to include(unmatched_run.public_id)
    expect(response.body).to include("ジョブ診断用の短い断片")
    expect(response.body).not_to include("raw-index-token-3891")
    expect(response.body).not_to include("raw-index-bearer-3891")
    expect(response.body).not_to include("/home/app/private-index-source.yml")
    expect(response.body).not_to include("/Users/alice/private-index-input.yml")
  end

  it "forbids external users from the generated file run detail" do
    sign_in_as(create(:user, :external))
    run = create_run!(metadata: {"access_token" => "external-user-secret-3673"})

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:forbidden)
    expect(response.body).not_to include("external-user-secret-3673")
  end

  def create_run!(attributes = {})
    defaults = {
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    }

    GeneratedFileRun.create!(defaults.merge(attributes))
  end
end
