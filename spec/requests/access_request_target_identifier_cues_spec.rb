require "rails_helper"

RSpec.describe "Access request target identifier cues", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "TARGET-PJ", name: "検索対象案件") }
  let(:document) { create(:document, project:, title: "検索対象文書", slug: "target-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "target-manual.pdf", content_type: "application/pdf", file_size: 10) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows searchable target identifiers without changing the request list contract" do
    create(:access_request, requester: user, requestable: project, requested_access_level: :manage, reason: "案件コードで探したい")
    create(:access_request, requester: user, requestable: document, requested_access_level: :download, reason: "文書IDで探したい")
    create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "ファイルIDで探したい")

    sign_in_as(user)

    get access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件コード: TARGET-PJ")
    expect(page_text).to include("対象ID: #{project.public_id}")
    expect(page_text).to include("文書ID: #{document.public_id}")
    expect(page_text).to include("ファイルID: #{file.public_id}")
    expect(page_text).to include("文書: 検索対象文書")
    expect(parsed_html.css("td p.muted code").map(&:text)).to include(
      "TARGET-PJ",
      project.public_id,
      document.public_id,
      file.public_id
    )
  end

  def parsed_html
    Nokogiri::HTML.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end
end
