require "rails_helper"

RSpec.describe Admin::AccessLogsHelper, type: :helper do
  describe "#access_log_active_filter_summaries" do
    it "renders active filters with readable labels" do
      project = build_stubbed(:project, id: 101, code: "AUDIT", name: "Audit Project")
      company = build_stubbed(:company, id: 202, domain: "audit.example.com", name: "Audit Company")
      user = build_stubbed(:user, id: 303, email_address: "owner@example.com", name: "owner", display_name: "Owner User")

      summaries = helper.access_log_active_filter_summaries(
        {
          action_type: "download",
          target_type: "zip",
          project_id: project.id.to_s,
          company_id: company.id.to_s,
          user_id: user.id.to_s,
          document_q: "Quarterly Audit",
          from: "2026-05-10",
          to: "2026-05-12"
        },
        projects: [project],
        companies: [company],
        users: [user]
      )

      expect(summaries).to eq([
        "操作: ダウンロード",
        "対象種別: ZIP",
        "案件: AUDIT / Audit Project",
        "会社: Audit Company / audit.example.com",
        "ユーザー: Owner User / owner@example.com",
        "文書名・URL識別子: Quarterly Audit",
        "開始日: 2026-05-10",
        "終了日: 2026-05-12"
      ])
    end

    it "does not expose raw ids when selected records are missing" do
      summaries = helper.access_log_active_filter_summaries(
        { project_id: "999", company_id: "888", user_id: "777", from: "not-a-date" },
        projects: [],
        companies: [],
        users: []
      )

      expect(summaries).to eq([
        "案件: 指定あり",
        "会社: 指定あり",
        "ユーザー: 指定あり",
        "開始日: 日付を確認"
      ])
    end
  end
end
