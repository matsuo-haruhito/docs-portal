require "rails_helper"

RSpec.describe "dashboard source" do
  let(:view_source) do
    Rails.root.join("app/views/dashboard/show.html.erb").read
  end

  it "uses structured resource list markup for dense dashboard cards" do
    expect(view_source.scan('class="resource-list__item"').size).to be >= 8
    expect(view_source.scan('class="resource-list__content"').size).to be >= 8
    expect(view_source.scan('resource-list__meta').size).to be >= 6

    expect(view_source).to include("@projects.each")
    expect(view_source).to include("@favorite_bookmarks.each")
    expect(view_source).to include("@read_later_bookmarks.each")
    expect(view_source).to include("@recent_documents.each")
    expect(view_source).to include("@recently_updated_documents.each")
  end

  it "keeps dashboard destinations and empty-state calls to action unchanged" do
    expect(view_source).to include("project_path(project)")
    expect(view_source).to include("project_document_path(bookmark.document.project, bookmark.document.slug)")
    expect(view_source).to include("project_document_path(document.project, document.slug)")
    expect(view_source).to include("document_bookmarks_path")
    expect(view_source).to include("access_requests_path")
    expect(view_source).to include("文書一覧へ")
    expect(view_source).to include("案件一覧へ")
  end
end
