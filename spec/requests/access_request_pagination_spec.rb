require "rails_helper"

RSpec.describe "Access request pagination", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "AREQ", name: "Access Request Project") }
  let(:document) { create(:document, project:, title: "Access Manual", slug: "access-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "access-manual.pdf", content_type: "application/pdf", file_size: 10) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user:)
    create(:project_membership, project:, user: other_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "paginates the current user's filtered requests while preserving filter params" do
    requests = Array.new(105) do |index|
      create(
        :access_request,
        requester: user,
        requestable: file,
        requested_access_level: :download,
        reason: "page request #{format("%03d", index + 1)}"
      )
    end
    create(:access_request, requester: other_user, requestable: file, requested_access_level: :download, reason: "other user page request")

    sign_in_as(user)

    get access_requests_path, params: {
      q: "page request",
      status: :pending,
      requested_access_level: :download,
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 1-100件 / 条件一致 105件（Page 1 / 2、100件ずつ）")
    expect(page_text).to include("申請中 105件 / 承認済み 0件 / 却下 0件 / 取消済み 0件")
    expect(page_text).to include(requests.last.reason)
    expect(page_text).not_to include(requests.first.reason)
    expect(page_text).not_to include("other user page request")

    next_link = parsed_html.css("a[href]").find { |link| link.text.squish == "次へ" }
    expect(next_link).to be_present
    next_params = Rack::Utils.parse_nested_query(URI.parse(next_link["href"]).query)
    expect(next_params).to include(
      "q" => "page request",
      "status" => "pending",
      "requested_access_level" => "download",
      "requestable_type" => "DocumentFile",
      "page" => "2"
    )

    get next_link["href"]

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 101-105件 / 条件一致 105件（Page 2 / 2、100件ずつ）")
    expect(page_text).to include(requests.first.reason)
    expect(page_text).not_to include(requests.last.reason)
    expect(page_text).not_to include("other user page request")

    previous_link = parsed_html.css("a[href]").find { |link| link.text.squish == "前へ" }
    expect(previous_link).to be_present
    previous_params = Rack::Utils.parse_nested_query(URI.parse(previous_link["href"]).query)
    expect(previous_params).to include(
      "q" => "page request",
      "status" => "pending",
      "requested_access_level" => "download",
      "requestable_type" => "DocumentFile",
      "page" => "1"
    )

    cancel_form = parsed_html.at_css(%(form[action="#{cancel_access_request_path(requests.first)}"]))
    expect(cancel_form).to be_present
    expect(cancel_form.at_css('input[name="q"]')["value"]).to eq("page request")
    expect(cancel_form.at_css('input[name="status"]')["value"]).to eq("pending")
    expect(cancel_form.at_css('input[name="requested_access_level"]')["value"]).to eq("download")
    expect(cancel_form.at_css('input[name="requestable_type"]')["value"]).to eq("DocumentFile")
    expect(cancel_form.at_css('input[name="page"]')["value"]).to eq("2")

    post cancel_access_request_path(requests.first), params: {
      q: " page request ",
      status: "pending",
      requested_access_level: "download",
      requestable_type: "DocumentFile",
      page: "2",
      unsupported: "drop-me"
    }

    expect(response).to redirect_to(access_requests_path(q: "page request", status: "pending", requested_access_level: "download", requestable_type: "DocumentFile", page: 2))
    expect(requests.first.reload).to be_cancelled
  end

  it "normalizes invalid and oversized page params" do
    Array.new(105) do |index|
      create(
        :access_request,
        requester: user,
        requestable: file,
        requested_access_level: :download,
        reason: "normalized page request #{format("%03d", index + 1)}"
      )
    end

    sign_in_as(user)

    get access_requests_path, params: { q: "normalized page", page: "invalid" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 1-100件 / 条件一致 105件（Page 1 / 2、100件ずつ）")

    get access_requests_path, params: { q: "normalized page", page: 99 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 101-105件 / 条件一致 105件（Page 2 / 2、100件ずつ）")
  end

  def parsed_html
    Nokogiri::HTML.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end
end
