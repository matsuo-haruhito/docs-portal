require "rails_helper"

RSpec.describe "Admin generated file runs index copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows Japanese labels while keeping status filter values" do
    sign_in_as(admin_user)
    run = create_run!(job_id: "ai_usecase_decision_flow", status: :failed)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("状態")
    expect(response.body).to include("ジョブID")
    expect(response.body).to include("ジェネレーター")
    expect(response.body).to include("出力先")
    expect(response.body).to include("イベント発生元")
    expect(response.body).to include("作成日(開始)")
    expect(response.body).to include("作成日(終了)")
    expect(response.body).to include("完了")
    expect(response.body).to include("失敗")
    expect(response.body).to include(%(value="failed"))
    expect(response.body).to include(admin_generated_file_runs_path(status: "failed"))
    expect(response.body).to include(run.public_id)
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
