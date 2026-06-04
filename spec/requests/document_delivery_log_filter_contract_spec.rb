require "rails_helper"

RSpec.describe "Document delivery log filter contract", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def create_log!(attributes = {})
    create(
      :document_delivery_log,
      {
        project:,
        document:,
        sender: external_user,
        status: :draft,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "Delivery notice",
        body: "Please review"
      }.merge(attributes)
    )
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "searches the documented query targets for internal users across senders" do
    other_sender = create(:user, :external, company:)
    project_name = create(:project, code: "PNAME", name: "Blue Contract Project")
    project_name_document = create(:document, project: project_name, title: "Project Name Target", slug: "project-name-target")
    project_code = create(:project, code: "QCODE1980", name: "Code Search Project")
    project_code_document = create(:document, project: project_code, title: "Project Code Target", slug: "project-code-target")
    non_matching = create_log!(to_addresses: "outside@example.com", subject: "No match", error_message: "not relevant")

    cases = [
      ["blue contract", create_log!(project: project_name, document: project_name_document, to_addresses: "project-name-hit@example.com")],
      ["qcode1980", create_log!(project: project_code, document: project_code_document, to_addresses: "project-code-hit@example.com")],
      ["primary-hit@example.com", create_log!(to_addresses: "primary-hit@example.com")],
      ["cc-hit@example.com", create_log!(to_addresses: "cc-owner@example.com", cc_addresses: "cc-hit@example.com")],
      ["bcc-hit@example.com", create_log!(to_addresses: "bcc-owner@example.com", bcc_addresses: "bcc-hit@example.com")],
      ["subject needle 1980", create_log!(to_addresses: "subject-hit@example.com", subject: "Subject needle 1980")],
      ["failure needle 1980", create_log!(to_addresses: "failure-hit@example.com", status: :failed, error_message: "Failure needle 1980")],
      ["other sender visible", create_log!(sender: other_sender, to_addresses: "other-sender-hit@example.com", subject: "Other sender visible")]
    ]

    sign_in_as(internal_user)

    cases.each do |query, log|
      get document_delivery_logs_path, params: { q: query }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include(log.to_addresses)
      expect(page_text).not_to include(non_matching.to_addresses)
    end
  end

  it "keeps external search limited to the current sender when query, status, and delivery type are combined" do
    other_sender = create(:user, :external, company:)
    visible_log = create_log!(status: :failed, delivery_type: :portal_link, to_addresses: "visible-target@example.com", subject: "Combined target")
    other_sender_log = create_log!(sender: other_sender, status: :failed, delivery_type: :portal_link, to_addresses: "other-target@example.com", subject: "Combined target")
    wrong_type_log = create_log!(status: :failed, delivery_type: :attachment, to_addresses: "wrong-type@example.com", subject: "Combined target")
    wrong_status_log = create_log!(status: :draft, delivery_type: :portal_link, to_addresses: "wrong-status@example.com", subject: "Combined target")

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { q: "Combined target", status: :failed, delivery_type: :portal_link }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(visible_log.to_addresses)
    expect(page_text).not_to include(other_sender_log.to_addresses)
    expect(page_text).not_to include(wrong_type_log.to_addresses)
    expect(page_text).not_to include(wrong_status_log.to_addresses)
    expect(page_text).to include("表示範囲: 1件中1件を表示しています。")
    expect(action_targets).to include(document_delivery_logs_path(q: "Combined target", status: :draft, delivery_type: :portal_link))
    expect(action_targets).to include(document_delivery_logs_path(q: "Combined target", status: :failed))
  end

  it "limits the rendered list to the latest 50 rows while preserving the total count summary" do
    sign_in_as(external_user)

    51.times do |index|
      create_log!(to_addresses: format("limit-%02d@example.com", index), subject: "Limit contract")
    end

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中50件を表示しています。")
    expect(page_text).to include("さらに絞り込む場合は検索・状態・方式フィルタを使ってください。")
    expect(parsed_html.css("tbody tr").size).to eq(50)
    expect(page_text).to include("limit-50@example.com")
    expect(page_text).not_to include("limit-00@example.com")
  end
end
