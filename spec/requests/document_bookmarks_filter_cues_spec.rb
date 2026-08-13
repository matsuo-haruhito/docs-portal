require "rails_helper"

RSpec.describe "Document bookmark filter cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  it "shows only the saved filter on saved tabs and carries view" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite", bookmark_q: "manual", recent_q: "guide" }

    expect(response).to have_http_status(:ok)
    expect(page.at_css("#favorite-bookmarks")).to be_present
    expect(page.at_css("#recent-documents")).to be_nil
    expect(page.at_css("form input[type='hidden'][name='view'][value='favorite']")).to be_present
    expect(page.at_css("form input[type='hidden'][name='recent_q'][value='guide']")).to be_present
  end

  it "shows only the recent filter on the recent tab and carries saved filters" do
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "recent", project_code: project.code, bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    recent_form = page.at_css("#recent-documents form")
    expect(recent_form.at_css("input[type='hidden'][name='view'][value='recent']")).to be_present
    expect(recent_form.at_css("input[type='hidden'][name='project_code'][value='#{project.code}']")).to be_present
    expect(recent_form.at_css("input[type='hidden'][name='bookmark_q'][value='manual']")).to be_present
    expect(page.at_css("#favorite-bookmarks, #read-later-bookmarks")).to be_nil
  end

  it "keeps view on section-local reset links" do
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "read_later", project_code: "missing", bookmark_q: "manual", recent_q: "guide" }

    reset_link = page.css("#read-later-bookmarks a").find { _1.text.squish == "保存済み条件を解除" }
    expect(reset_link).to be_present
    expect(reset_link["href"]).to include("view=read_later", "recent_q=guide")
    expect(reset_link["href"]).not_to include("project_code", "bookmark_q")
  end
end
