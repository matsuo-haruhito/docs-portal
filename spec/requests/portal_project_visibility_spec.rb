require "rails_helper"

RSpec.describe "Portal project visibility", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def add_project_membership(project, user = external_user)
    create(:project_membership, project:, user:)
  end

  def grant_company_document_access(document, user = external_user)
    create(:document_permission, document:, company: user.company, user: nil)
  end

  def add_version(document, **attributes)
    version = create(:document_version, { document: }.merge(attributes))
    document.update!(latest_version: version)
    version
  end

  it "keeps external project index visibility while avoiding invisible document projects" do
    visible_project = create(:project, code: "PORTAL01", name: "Visible Portal Project")
    hidden_project = create(:project, code: "PORTAL02", name: "Hidden Portal Project")
    expired_project = create(:project, code: "PORTAL03", name: "Expired Portal Project")
    empty_project = create(:project, code: "PORTAL04", name: "Empty Portal Project")
    [visible_project, hidden_project, expired_project, empty_project].each { add_project_membership(_1) }

    visible_document = create(:document, project: visible_project, title: "Visible Portal Guide", slug: "visible-portal-guide")
    grant_company_document_access(visible_document)
    add_version(visible_document, version_label: "visible", published_from: 1.day.ago, published_until: 1.day.from_now)

    hidden_document = create(:document, project: hidden_project, title: "Hidden Portal Guide", slug: "hidden-portal-guide")
    add_version(hidden_document, version_label: "hidden")

    expired_document = create(:document, project: expired_project, title: "Expired Portal Guide", slug: "expired-portal-guide")
    grant_company_document_access(expired_document)
    add_version(expired_document, version_label: "expired", published_from: 3.days.ago, published_until: 1.day.ago)

    sign_in_as(external_user)

    get projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Visible Portal Project")
    expect(page_text).to include("Empty Portal Project")
    expect(page_text).not_to include("Hidden Portal Project")
    expect(page_text).not_to include("Expired Portal Project")
    expect(page_text).not_to include("Hidden Portal Guide")
    expect(page_text).not_to include("Expired Portal Guide")
  end

  it "keeps the current project in the tree even when it has no portal-visible documents" do
    empty_project = create(:project, code: "PORTAL05", name: "Current Empty Project")
    other_project = create(:project, code: "PORTAL06", name: "Other Hidden Project")
    add_project_membership(empty_project)
    add_project_membership(other_project)

    hidden_document = create(:document, project: other_project, title: "Other Hidden Guide", slug: "other-hidden-guide")
    add_version(hidden_document, version_label: "hidden")

    sign_in_as(external_user)

    get project_path(empty_project)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Current Empty Project")
    expect(page_text).not_to include("Other Hidden Project")
    expect(page_text).not_to include("Other Hidden Guide")
  end

  it "prefilters document page tree candidates but preserves the final portal visibility guard" do
    visible_project = create(:project, code: "PORTAL07", name: "Tree Visible Project")
    hidden_project = create(:project, code: "PORTAL08", name: "Tree Hidden Project")
    [visible_project, hidden_project].each { add_project_membership(_1) }

    visible_document = create(:document, project: visible_project, title: "Tree Visible Guide", slug: "tree-visible-guide")
    grant_company_document_access(visible_document)
    add_version(visible_document, version_label: "visible", source_relative_path: "guides/tree-visible-guide.md")

    hidden_document = create(:document, project: hidden_project, title: "Tree Hidden Guide", slug: "tree-hidden-guide")
    add_version(hidden_document, version_label: "hidden", source_relative_path: "guides/tree-hidden-guide.md")

    sign_in_as(external_user)

    get project_document_path(visible_project, visible_document.slug)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Tree Visible Project")
    expect(page_text).to include("tree-visible-guide.md")
    expect(page_text).not_to include("Tree Hidden Project")
    expect(page_text).not_to include("tree-hidden-guide.md")
  end
end
