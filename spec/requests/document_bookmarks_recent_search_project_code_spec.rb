require "rails_helper"

RSpec.describe "Document bookmark recent search project code", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  def grant_access(document)
    ProjectMembership.find_or_create_by!(project: document.project, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def mark_recent(document, accessed_at: Time.current)
    create(:access_log, user:, company:, project: document.project, document:, action_type: :view, target_type: "document", accessed_at:)
  end

  it "filters the recent panel by project code and preserves recent view" do
    project = create(:project, name: "Alpha Workspace", code: "ALPHA2397")
    other_project = create(:project, name: "Beta Workspace", code: "BETA2397")
    matching = create(:document, project:, title: "Quarterly Plan", slug: "quarterly-plan", visibility_policy: :restricted_external)
    other = create(:document, project: other_project, title: "Operations Guide", slug: "operations-guide", visibility_policy: :restricted_external)
    [matching, other].each { grant_access(_1) }
    mark_recent(matching, accessed_at: 2.minutes.ago)
    mark_recent(other, accessed_at: 1.minute.ago)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "recent", recent_q: "alpha2397" }

    html = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quarterly Plan")
    expect(response.body).not_to include("Operations Guide")
    expect(html.at_css("#recent-documents")).to be_present
    expect(html.at_css("input[type='hidden'][name='view'][value='recent']")).to be_present
  end

  it "shows read-only next-step links when recent search has no match" do
    project = create(:project, name: "Visible Project", code: "VISIBLE")
    document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    grant_access(document)
    mark_recent(document)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "recent", recent_q: "not-found" }

    links = Nokogiri::HTML(response.body).css("#recent-documents a").map { _1.text.squish }
    expect(links).to include("最近見た条件をクリア", "案件一覧から探す", "文書一覧から探す")
    expect(response.body).not_to include("Guide")
  end
end
