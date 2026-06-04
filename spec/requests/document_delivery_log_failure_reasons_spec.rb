require "rails_helper"

RSpec.describe "Document delivery log failure reasons", type: :request do
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "DLVFR", name: "Delivery Failure Project") }
  let(:document) { create(:document, project:, title: "Failure Manual", slug: "failure-manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def failure_form
    parsed_html.css("form").find do |form|
      form.at_css("input[name='decision'][value='mark_failed']").present?
    end
  end

  def mark_sent_form
    parsed_html.css("form").find do |form|
      form.at_css("input[name='decision'][value='mark_sent']").present?
    end
  end

  it "shows a failure reason input while preserving the filtered return path" do
    log = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft)
    return_to = document_delivery_logs_path(status: :draft, delivery_type: :portal_link)

    sign_in_as(external_user)

    get document_delivery_log_path(log), params: { return_to: }

    expect(response).to have_http_status(:ok)
    expect(failure_form).to be_present
    expect(failure_form.at_css("label[for='error_message']").text).to include("失敗理由")
    expect(failure_form.at_css("input[name='error_message']")[:maxlength]).to eq("200")
    expect(failure_form.at_css("input[name='return_to']")[:value]).to eq(return_to)
    expect(mark_sent_form.at_css("input[name='return_to']")[:value]).to eq(return_to)
  end

  it "stores the entered failure reason when a draft is marked failed" do
    log = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft)
    return_to = document_delivery_logs_path(status: :draft)

    sign_in_as(external_user)

    patch document_delivery_log_path(log), params: {
      decision: "mark_failed",
      error_message: "宛先確認待ち",
      return_to:
    }

    expect(response).to redirect_to(document_delivery_log_path(log, return_to:))
    expect(log.reload.status).to eq("failed")
    expect(log.error_message).to eq("宛先確認待ち")
  end

  it "keeps the existing manual mark fallback when the failure reason is blank" do
    log = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft)

    sign_in_as(external_user)

    patch document_delivery_log_path(log), params: { decision: "mark_failed", error_message: "" }

    expect(response).to redirect_to(document_delivery_log_path(log))
    expect(log.reload.status).to eq("failed")
    expect(log.error_message).to eq("manual mark")
  end

  it "leaves mark_sent independent of the failure reason input" do
    log = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft, error_message: "previous failure note")

    sign_in_as(external_user)

    patch document_delivery_log_path(log), params: { decision: "mark_sent" }

    expect(response).to redirect_to(document_delivery_log_path(log))
    expect(log.reload.status).to eq("sent")
    expect(log.sent_at).to be_present
    expect(log.error_message).to be_nil
  end
end
