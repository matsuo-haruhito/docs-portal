require "rails_helper"

RSpec.describe Admin::AccessLogsHelper, type: :helper do
  describe "#access_log_active_filter_summaries" do
    it "renders active filters with readable labels" do
      project = build_stubbed(:project, id: 101, code: "AUDIT", name: "Audit Project")
      company = build_stubbed(:company, id: 202, domain: "audit.example.com", name: "Audit Company")
      user = build_stubbed(:user, id: 303, email_address: "owner@example.com", name: "Owner User")

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

  describe "#access_log_ai_context_target_details" do
    def build_log(target_type:, target_name:)
      instance_double(AccessLog, target_type: target_type, target_name: target_name)
    end

    it "splits a known ai_context target_name into readable segments" do
      log = build_log(
        target_type: "ai_context",
        target_name: "mode=compact;scope=selected;selected_count=3;exported_count=2"
      )

      details = helper.access_log_ai_context_target_details(log)

      expect(details).to eq(
        preview: "mode=compact;scope=selected;selected_count=3;exported_count=2",
        segments: [
          { label: "AI出力モード", value: "コンパクト" },
          { label: "AI出力範囲", value: "選択" },
          { label: "選択数", value: "3件" },
          { label: "出力数", value: "2件" }
        ]
      )
      expect(details.fetch(:segments).map { _1.fetch(:label) }).not_to include("mode", "scope")
    end

    it "keeps all-scope context readable" do
      log = build_log(
        target_type: "ai_context",
        target_name: "mode=full;scope=all;selected_count=0;exported_count=12"
      )

      details = helper.access_log_ai_context_target_details(log)

      expect(details[:segments]).to include(
        { label: "AI出力モード", value: "詳細" },
        { label: "AI出力範囲", value: "全件" },
        { label: "選択数", value: "0件" },
        { label: "出力数", value: "12件" }
      )
    end

    it "returns a safe preview for malformed ai_context target names" do
      malformed_log = build_log(target_type: "ai_context", target_name: "mode=compact;scope=selected")
      non_numeric_log = build_log(
        target_type: "ai_context",
        target_name: "mode=compact;scope=selected;selected_count=many;exported_count=2"
      )
      sensitive_log = build_log(
        target_type: "ai_context",
        target_name: "authorization=Bearer raw-token-123;secret=raw-secret-456;/home/alice/private.txt"
      )

      expect(helper.access_log_ai_context_target_details(malformed_log)).to eq(
        preview: "mode=compact;scope=selected",
        segments: []
      )
      expect(helper.access_log_ai_context_target_details(non_numeric_log)).to eq(
        preview: "mode=compact;scope=selected;selected_count=many;exported_count=2",
        segments: []
      )
      expect(helper.access_log_ai_context_target_details(sensitive_log)).to eq(
        preview: "authorization=[FILTERED] [FILTERED];secret=[FILTERED];[path hidden]",
        segments: []
      )
    end

    it "does not change other target types" do
      log = build_log(target_type: "page", target_name: "docs/setup")

      expect(helper.access_log_ai_context_target_details(log)).to be_nil
    end
  end
end
