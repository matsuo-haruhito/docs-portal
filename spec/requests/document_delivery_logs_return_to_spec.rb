require "rails_helper"

RSpec.describe "Document delivery log return_to safety", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def form_param_for_submit(submit_value, param_name)
    form = parsed_html.css("form").find do |node|
      node.css("input, button").any? { |control| control["value"] == submit_value || control.text.strip == submit_value }
    end
    form&.at_css("input[name='#{param_name}']")&.[]("value")
  end

  def unsafe_return_to_values
    [
      "",
      "//evil.example/path",
      "https://evil.example/path",
      "http://evil.example/path",
      "javascript:alert(1)",
      "#section",
      "/document_delivery_logs\nSet-Cookie: bad=1"
    ]
  end

  def create_draft_delivery_log
    create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "client@example.com",
      subject: "Delivery notice"
    )
  end

  before do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "keeps internal filtered list paths in the detail link and manual update forms" do
    sign_in_as(external_user)
    delivery_log = create_draft_delivery_log
    return_to = document_delivery_logs_path(
      q: "DLV1",
      status: :draft,
      delivery_type: :portal_link,
      created_from: "2026-01-10",
      sent_to: "2026-01-20"
    )

    get document_delivery_log_path(delivery_log), params: { return_to: return_to }

    expect(response).to have_http_status(:ok)
    expect(href_for("送付履歴一覧へ戻る")).to eq(return_to)
    expect(form_param_for_submit("送付済みにする", "return_to")).to eq(return_to)
    expect(form_param_for_submit("送付失敗として記録", "return_to")).to eq(return_to)

    patch document_delivery_log_path(delivery_log), params: { decision: "mark_sent", return_to: return_to }

    expect(response).to redirect_to(document_delivery_log_path(delivery_log, return_to: return_to))
    expect(delivery_log.reload.status).to eq("sent")
  end

  it "falls back for unsafe return_to values in the detail link and manual update forms" do
    sign_in_as(external_user)
    delivery_log = create_draft_delivery_log
    fallback = document_delivery_logs_path

    unsafe_return_to_values.each do |return_to|
      get document_delivery_log_path(delivery_log), params: { return_to: return_to }

      expect(response).to have_http_status(:ok)
      expect(href_for("送付履歴一覧へ戻る")).to eq(fallback)
      expect(form_param_for_submit("送付済みにする", "return_to")).to eq(fallback)
      expect(form_param_for_submit("送付失敗として記録", "return_to")).to eq(fallback)
    end
  end

  it "falls back for unsafe return_to values after manual delivery log updates" do
    sign_in_as(external_user)
    fallback = document_delivery_logs_path

    unsafe_return_to_values.each do |return_to|
      delivery_log = create_draft_delivery_log

      patch document_delivery_log_path(delivery_log), params: { decision: "mark_failed", return_to: return_to, error_message: "manual failure" }

      expect(response).to redirect_to(document_delivery_log_path(delivery_log, return_to: fallback))
      expect(delivery_log.reload.status).to eq("failed")
      expect(delivery_log.error_message).to eq("manual failure")
    end
  end
end
