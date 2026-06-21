require "rails_helper"

RSpec.describe "Admin dashboard configuration diagnostic filters", type: :request do
  DiagnosticCheck = Struct.new(:status, :key, :label, :message, :detail, keyword_init: true)

  let(:admin_user) { create(:user, :internal) }
  let(:diagnostic_checks) do
    [
      DiagnosticCheck.new(status: :ok, key: "SECRET_KEY_BASE", label: "secret ready", message: "secret is configured"),
      DiagnosticCheck.new(status: :warning, key: "ACTIVE_STORAGE_SERVICE", label: "storage warning", message: "storage needs review"),
      DiagnosticCheck.new(status: :error, key: "KROKI_ENDPOINT", label: "workspace error", message: "workspace is unavailable")
    ]
  end
  let(:diagnostic_result) do
    instance_double(
      "ApplicationConfigurationDiagnostic::Result",
      checks: diagnostic_checks,
      ok_count: 1,
      warning_count: 1,
      error_count: 1,
      healthy?: false
    )
  end

  before do
    allow(ApplicationConfigurationDiagnostic).to receive(:new).and_return(instance_double(ApplicationConfigurationDiagnostic, call: diagnostic_result))
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def dashboard_section(title)
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == title }
  end

  def configuration_section_text
    dashboard_section("アプリ設定診断").text.squish
  end

  it "filters diagnostic rows by status while keeping the overall summary visible" do
    sign_in_as(admin_user)

    get admin_root_path, params: { configuration_status: "warning" }

    expect(response).to have_http_status(:ok)
    expect(configuration_section_text).to include("OK: 1 / 警告: 1 / エラー: 1")
    expect(configuration_section_text).to include("絞り込み中（状態: 警告）: 全3件中 1件を表示しています。")
    expect(configuration_section_text).to include("storage warning")
    expect(configuration_section_text).not_to include("secret ready")
    expect(configuration_section_text).not_to include("workspace error")
  end

  it "filters diagnostic rows by the existing category labels" do
    sign_in_as(admin_user)

    get admin_root_path, params: { configuration_category: "workspace" }

    expect(response).to have_http_status(:ok)
    expect(configuration_section_text).to include("絞り込み中（カテゴリ: Workspace）: 全3件中 1件を表示しています。")
    expect(configuration_section_text).to include("workspace error")
    expect(configuration_section_text).not_to include("secret ready")
    expect(configuration_section_text).not_to include("storage warning")
  end

  it "explains that a zero row filter result is not the same as a healthy diagnostic" do
    sign_in_as(admin_user)

    get admin_root_path, params: { configuration_status: "warning", configuration_category: "workspace" }

    expect(response).to have_http_status(:ok)
    expect(configuration_section_text).to include("絞り込み中（状態: 警告 / カテゴリ: Workspace）: 全3件中 0件を表示しています。")
    expect(configuration_section_text).to include("現在の絞り込み条件に一致する診断項目はありません。")
    expect(configuration_section_text).to include("診断全体が正常という意味ではない")
    expect(configuration_section_text).not_to include("secret ready")
    expect(configuration_section_text).not_to include("storage warning")
    expect(configuration_section_text).not_to include("workspace error")
  end

  it "ignores invalid filter params and renders all diagnostic rows" do
    sign_in_as(admin_user)

    get admin_root_path, params: { configuration_status: "unknown", configuration_category: "other" }

    expect(response).to have_http_status(:ok)
    expect(configuration_section_text).to include("全3件を表示しています。状態またはカテゴリで表示行だけを絞り込めます。")
    expect(configuration_section_text).to include("secret ready")
    expect(configuration_section_text).to include("storage warning")
    expect(configuration_section_text).to include("workspace error")
  end
end
