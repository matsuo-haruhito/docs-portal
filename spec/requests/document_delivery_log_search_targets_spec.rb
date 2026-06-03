require "rails_helper"

RSpec.describe "Document delivery log search targets", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  before do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "searches by cc, bcc, subject, and failure reason while preserving filters" do
    cc_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "cc-visible@example.com",
      cc_addresses: "copy-audit@example.com",
      subject: "Ordinary draft",
      body: "No body search marker"
    )
    bcc_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "bcc-visible@example.com",
      bcc_addresses: "blind-audit@example.com",
      subject: "Ordinary bcc draft"
    )
    subject_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :sent,
      delivery_type: :attachment,
      to_addresses: "subject-visible@example.com",
      subject: "Quarterly Pack Review"
    )
    failure_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :failed,
      delivery_type: :zip_attachment,
      to_addresses: "failure-visible@example.com",
      subject: "Failure notice",
      error_message: "SMTP quota exceeded"
    )
    wrong_delivery_type_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :failed,
      delivery_type: :portal_link,
      to_addresses: "wrong-delivery-type@example.com",
      subject: "Other failure notice",
      error_message: "SMTP quota exceeded"
    )
    body_only_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "body-only@example.com",
      subject: "Body-only marker",
      body: "hidden-body-marker"
    )

    sign_in_as(internal_user)

    get document_delivery_logs_path, params: { q: "copy-audit" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(cc_log.to_addresses)
    expect(page_text).not_to include(bcc_log.to_addresses)
    expect(page_text).not_to include(subject_log.to_addresses)
    expect(page_text).not_to include(failure_log.to_addresses)

    get document_delivery_logs_path, params: { q: "blind-audit" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(bcc_log.to_addresses)
    expect(page_text).not_to include(cc_log.to_addresses)

    get document_delivery_logs_path, params: { q: "quarterly pack" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(subject_log.to_addresses)
    expect(page_text).not_to include(cc_log.to_addresses)

    get document_delivery_logs_path, params: { q: "smtp quota", status: :failed, delivery_type: :zip_attachment }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(failure_log.to_addresses)
    expect(page_text).not_to include(wrong_delivery_type_log.to_addresses)
    expect(page_text).not_to include(cc_log.to_addresses)

    get document_delivery_logs_path, params: { q: "hidden-body-marker" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する送付履歴はありません。")
    expect(page_text).not_to include(body_only_log.to_addresses)
  end

  it "keeps expanded search targets limited to the current external sender" do
    other_external_user = create(:user, :external, company:)
    own_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "own-copy@example.com",
      cc_addresses: "private-copy@example.com"
    )
    other_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: other_external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "other-copy@example.com",
      cc_addresses: "private-copy@example.com"
    )

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { q: "private-copy" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(own_log.to_addresses)
    expect(page_text).not_to include(other_log.to_addresses)
  end

  it "shows the current search target hint in the index form" do
    sign_in_as(internal_user)

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件名・案件コード・宛先/CC/BCC・件名・失敗理由で検索")
  end
end
