require "rails_helper"

RSpec.describe "Admin generated file run preview cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows diagnostic preview boundaries without exposing raw sensitive values" do
    sign_in_as(admin_user)
    run = GeneratedFileRun.create!(
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :failed,
      event_source: "spec",
      source_paths: ["docs/source.yml"],
      changed_files: ["docs/changed.yml"],
      generated_paths: ["generated/output.md"],
      error_message: "token=raw-secret-value failed at /Users/alice/private.log",
      metadata: {
        "token" => "raw-secret-value",
        "safe_note" => "visible note",
        "private_path" => "/Users/alice/private.log"
      },
      started_at: 1.minute.ago,
      finished_at: Time.current
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("入力パスはジョブ診断用の配列表示です。生成ジョブの入力を再確認する手がかりとして扱います。")
      expect(page_text).to include("変更ファイルはジョブ診断用の配列表示です。生成前後の差分を再確認する手がかりとして扱います。")
      expect(page_text).to include("生成パスはジョブ診断用の配列表示です。出力先の確認入口として扱います。")
      expect(page_text).to include("メタデータは診断用プレビューです。token / secret / private path は表示前に伏せています。")
      expect(page_text).to include("エラーは診断用プレビューです。長い本文は省略され、token / secret / private path は伏せています。")
      expect(page_text).to include("visible note")
      expect(page_text).to include(Admin::GeneratedFileRunsHelper::GENERATED_FILE_RUN_FILTERED_VALUE)
      expect(response.body).not_to include("raw-secret-value")
      expect(response.body).not_to include("/Users/alice/private.log")
    end
  end
end
