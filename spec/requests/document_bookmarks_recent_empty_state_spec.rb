require "rails_helper"

RSpec.describe "Document bookmark recent empty state", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "puts a recent clear link near the filtered empty state while keeping saved filters" do
    recent_document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: {
      project_code: project.code,
      bookmark_q: "manual",
      recent_q: "zzz",
      favorite_page: 2,
      read_later_page: 3
    }

    expect(response).to have_http_status(:ok)

    parsed_html = Nokogiri::HTML(response.body)
    recent_section = parsed_html.css("section").find { |section| section.at_css("h2")&.text&.include?("最近見た文書") }

    expect(recent_section.text.squish).to include("最近見た文書検索「zzz」に一致する文書は、最近表示された最大 20 件内にありません。")

    empty_state_clear_link = recent_section.css("p.actions a").find { |link| link.text.squish == "最近見た条件をクリア" }
    expect(empty_state_clear_link).to be_present
    expect(empty_state_clear_link["href"]).to eq(
      document_bookmarks_path(
        project_code: project.code,
        bookmark_q: "manual",
        favorite_page: 1,
        read_later_page: 1
      )
    )
    expect(empty_state_clear_link["href"]).not_to include("recent_q")
  end
end
