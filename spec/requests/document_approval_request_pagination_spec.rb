require "rails_helper"

RSpec.describe "Document approval request pagination", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:approver) { create(:user, :internal, name: "確認 花子") }
  let(:project) { create(:project, code: "APR-PAGE", name: "Approval Paging Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-page-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "paginates the global index while preserving filters and return_to" do
    requests = Array.new(55) do |index|
      create(
        :document_approval_request,
        document:,
        requester:,
        approver:,
        title: "ページ対象 #{format("%03d", index + 1)}"
      )
    end

    sign_in_as(internal_user)

    get document_approval_requests_path, params: {
      status: :pending,
      q: "ページ対象",
      requester_id: requester.id,
      approver_id: approver.id
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示 1-50件 / 条件一致 55件（Page 1 / 2、50件ずつ）")
    expect(response.body).to include(requests.last.title)
    expect(response.body).not_to include(requests.first.title)

    next_link = parsed_html.css("a[href]").find { |link| link.text.squish == "次へ" }
    expect(next_link).to be_present
    next_params = Rack::Utils.parse_nested_query(URI.parse(next_link["href"]).query)
    expect(next_params).to include(
      "status" => "pending",
      "q" => "ページ対象",
      "requester_id" => requester.id.to_s,
      "approver_id" => approver.id.to_s,
      "page" => "2"
    )

    get next_link["href"]
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示 51-55件 / 条件一致 55件（Page 2 / 2、50件ずつ）")
    expect(response.body).to include(requests.first.title)
    expect(response.body).not_to include(requests.last.title)

    detail_link = parsed_html.css(%(a[href^="#{document_approval_request_path(requests.first)}"])).find { |link| link.text == requests.first.title }
    expect(detail_link).to be_present
    detail_params = Rack::Utils.parse_nested_query(URI.parse(detail_link["href"]).query)
    return_to = URI.parse(detail_params.fetch("return_to"))
    return_to_params = Rack::Utils.parse_nested_query(return_to.query)
    expect(return_to.path).to eq(document_approval_requests_path)
    expect(return_to_params).to include(
      "status" => "pending",
      "q" => "ページ対象",
      "requester_id" => requester.id.to_s,
      "approver_id" => approver.id.to_s,
      "page" => "2"
    )
  end

  it "bounds per_page and keeps nested document pagination inside the document scope" do
    requests = Array.new(105) do |index|
      create(
        :document_approval_request,
        document:,
        requester:,
        approver:,
        title: "対象内ページ #{format("%03d", index + 1)}"
      )
    end
    other_document = create(:document, project:, title: "対象外資料", slug: "approval-other-doc", visibility_policy: :restricted_external)
    create(:document_permission, document: other_document, company:, access_level: :view)
    other_request = create(:document_approval_request, document: other_document, requester:, approver:, title: "対象外ページ")

    sign_in_as(internal_user)

    get project_document_document_approval_requests_path(project, document), params: { page: 2, per_page: 200 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示 101-105件 / 条件一致 105件（Page 2 / 2、100件ずつ）")
    expect(response.body).to include(requests.first.title)
    expect(response.body).not_to include(requests.last.title)
    expect(response.body).not_to include(other_request.title)

    previous_link = parsed_html.css("a[href]").find { |link| link.text.squish == "前へ" }
    expect(previous_link).to be_present
    previous_params = Rack::Utils.parse_nested_query(URI.parse(previous_link["href"]).query)
    expect(previous_params).to include("page" => "1", "per_page" => "100")
  end
end
