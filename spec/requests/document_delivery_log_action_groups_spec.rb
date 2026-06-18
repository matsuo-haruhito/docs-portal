require "rails_helper"

RSpec.describe "Document delivery log action groups", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def action_labels
    parsed_html.css("a, button, input[type='submit']").map { |node| node["value"].presence || node.text.strip }
  end

  def form_param_for_submit(submit_value, param_name)
    form = parsed_html.css("form").find do |node|
      node.css("input, button").any? { |control| control["value"] == submit_value || control.text.strip == submit_value }
    end
    form&.at_css("input[name='#{param_name}']")&.[]("value")
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "separates mailer launch, manual state updates, and target navigation for a draft" do
    log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "client@example.com",
      subject: "Please review",
      body: "Portal link"
    )
    return_to = document_delivery_logs_path(q: "DLV1", status: :draft, delivery_type: :portal_link)

    sign_in_as(external_user)

    get document_delivery_log_path(log), params: { return_to: return_to }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("メール作成")
    expect(page_text).to include("送付記録の状態はここでは変わりません。")
    expect(page_text).to include("手動状態更新")
    expect(page_text).to include("外部メーラーで送付した結果を、この送付履歴に記録します。")
    expect(page_text).to include("対象へ戻る")
    expect(page_text).to include("送付対象の文書・文書セット・案件を確認します。")
    expect(href_for("メーラーを開く")).to start_with("mailto:")
    expect(href_for("対象の文書へ戻る")).to eq(project_document_path(project, document.slug))
    expect(href_for("送付履歴一覧へ戻る")).to eq(return_to)
    expect(form_param_for_submit("送付済みにする", "return_to")).to eq(return_to)
    expect(form_param_for_submit("送付失敗として記録", "return_to")).to eq(return_to)
  end

  it "explains why manual state update actions are hidden once the delivery log is no longer a draft" do
    log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :sent,
      delivery_type: :portal_link,
      to_addresses: "client@example.com",
      subject: "Sent notice",
      body: "Portal link"
    )

    sign_in_as(external_user)

    get document_delivery_log_path(log)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("メール作成")
    expect(page_text).to include("対象へ戻る")
    expect(page_text).to include("手動状態更新")
    expect(page_text).to include("この履歴は下書きではないため、手動状態更新はできません。")
    expect(action_labels).not_to include("送付済みにする", "送付失敗として記録")
    expect(href_for("対象の文書へ戻る")).to eq(project_document_path(project, document.slug))
  end
end
