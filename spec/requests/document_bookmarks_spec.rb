require "rails_helper"

RSpec.describe "Document bookmarks", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows bookmark lists with project context and section cues" do
    later_document = create(:document, project:, title: "Checklist", slug: "checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ショートカット")
    expect(response.body).to include("保存済みショートカットの絞り込み")
    expect(response.body).to include("明示的に保存したお気に入りと後で読むだけを、案件や文書名・案件名で絞り込めます。")
    expect(response.body).to include("保存済みショートカットを検索")
    expect(response.body).to include("文書名・案件名・案件コード")
    expect(response.body).to include("Manual")
    expect(response.body).to include("Checklist")
    expect(response.body).to include("Guide")
    expect(response.body).to include("Visible Project")
    expect(response.body).to include("お気に入り")
    expect(response.body).to include("後で読む")
    expect(response.body).to include("最近見た文書")
    expect(response.body.scan("1件").size).to eq(3)
    expect(response.body).to include("よく開く文書をここからすぐ確認できます。")
    expect(response.body).to include("あとで確認したい文書を一時的に集めておけます。")
    expect(response.body).to include("閲覧履歴から自動で表示されます。お気に入りや後で読むとは別の一覧です。")
    expect(response.body).to include("最近見た文書を検索")
    expect(response.body).to include("文書名・案件名で検索")
    expect(response.body).to include("よく開く文書")
    expect(response.body).to include("あとで確認")
    expect(response.body).to include("最近見た文書")
    expect(response.body.scan("解除").size).to eq(2)
    expect(response.body.scan("お気に入りへ移す").size).to eq(1)
  end

  it "filters favorite and read-later bookmarks by project without filtering recent documents" do
    other_project = create(:project, name: "Other Project")
    later_document = create(:document, project: other_project, title: "Other Checklist", slug: "other-checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project: other_project, title: "Other Guide", slug: "other-guide", visibility_policy: :restricted_external)
    create(:project_membership, project: other_project, user:)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project: other_project, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { project_code: project.code }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件「Visible Project」でお気に入りと後で読むを絞り込んでいます。最近見た文書は絞り込み対象外です。")
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Other Checklist")
    expect(response.body).to include("Other Guide")
    expect(response.body).to include("案件「Visible Project」では後で読む文書が見つかりません。")
    expect(response.body).to include("解除")
    expect(response.body).not_to include("お気に入りへ移す")
    expect(response.body.scan("1件").size).to eq(2)
    expect(response.body.scan("0件").size).to eq(1)
  end

  it "filters saved favorite and read-later bookmarks by bookmark query without filtering recent documents" do
    later_document = create(:document, project:, title: "Release Checklist", slug: "release-checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project:, title: "Recent Guide", slug: "recent-guide", visibility_policy: :restricted_external)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索語「manual」でお気に入りと後で読むを絞り込んでいます。最近見た文書は絞り込み対象外です。")
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Release Checklist")
    expect(response.body).to include("Recent Guide")
    expect(response.body).to include("保存済みショートカット検索「manual」に一致する後で読む文書はありません。")
  end

  it "filters saved bookmarks by project name and code across favorite and read-later sections" do
    searchable_project = create(:project, name: "Alpha Workspace", code: "ALPHA2397")
    favorite_document = create(:document, project: searchable_project, title: "Launch Manual", slug: "launch-manual", visibility_policy: :restricted_external)
    later_document = create(:document, project: searchable_project, title: "Launch Checklist", slug: "launch-checklist", visibility_policy: :restricted_external)
    create(:project_membership, project: searchable_project, user:)
    create(:document_permission, document: favorite_document, company:, access_level: :view)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_bookmark, user:, document: favorite_document, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path, params: { bookmark_q: "alpha2397" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Launch Manual")
    expect(response.body).to include("Launch Checklist")
    expect(response.body.scan("1件").size).to eq(2)
  end

  it "combines project bookmark filtering with saved bookmark query" do
    other_project = create(:project, name: "Other Project")
    matching_document = create(:document, project:, title: "Project Manual", slug: "project-manual", visibility_policy: :restricted_external)
    project_miss_document = create(:document, project:, title: "Project Checklist", slug: "project-checklist", visibility_policy: :restricted_external)
    other_document = create(:document, project: other_project, title: "Other Manual", slug: "other-manual", visibility_policy: :restricted_external)
    create(:project_membership, project: other_project, user:)
    [matching_document, project_miss_document, other_document].each do |bookmark_document|
      create(:document_permission, document: bookmark_document, company:, access_level: :view)
    end
    create(:document_bookmark, user:, document: matching_document, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: project_miss_document, bookmark_type: :read_later)
    create(:document_bookmark, user:, document: other_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { project_code: project.code, bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件「Visible Project」と検索語「manual」でお気に入りと後で読むを絞り込んでいます。最近見た文書は絞り込み対象外です。")
    expect(response.body).to include("Project Manual")
    expect(response.body).not_to include("Project Checklist")
    expect(response.body).not_to include("Other Manual")
    expect(response.body).to include("保存済みショートカット検索「manual」に一致する後で読む文書はありません。")
  end

  it "shows saved bookmark search empty states separately from unregistered states" do
    later_document = create(:document, project:, title: "Checklist", slug: "checklist", visibility_policy: :restricted_external)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path, params: { bookmark_q: "zzz" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存済みショートカット検索「zzz」に一致するお気に入りはありません。")
    expect(response.body).to include("保存済みショートカット検索「zzz」に一致する後で読む文書はありません。")
    expect(response.body).not_to include("文書画面でお気に入りに追加すると、ここに表示されます。")
    expect(response.body).not_to include("文書画面で後で読むに追加すると、ここに表示されます。")
  end

  it "filters recent documents by query without filtering saved shortcuts" do
    beta_project = create(:project, name: "Beta Project")
    beta_document = create(:document, project: beta_project, title: "Quarterly Plan", slug: "quarterly-plan", visibility_policy: :restricted_external)
    other_recent_document = create(:document, project:, title: "Operations Guide", slug: "operations-guide", visibility_policy: :restricted_external)
    hidden_document = create(:document, project: beta_project, title: "Beta Hidden Notes", slug: "beta-hidden-notes", visibility_policy: :restricted_external)
    later_document = create(:document, project:, title: "Checklist", slug: "checklist", visibility_policy: :restricted_external)
    create(:project_membership, project: beta_project, user:)
    create(:document_permission, document: beta_document, company:, access_level: :view)
    create(:document_permission, document: other_recent_document, company:, access_level: :view)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project: beta_project, document: beta_document, action_type: :view, target_type: "document", accessed_at: 2.minutes.ago)
    create(:access_log, user:, company:, project:, document: other_recent_document, action_type: :view, target_type: "document", accessed_at: 1.minute.ago)
    create(:access_log, user:, company:, project: beta_project, document: hidden_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { recent_q: "beta" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).to include("Checklist")
    expect(response.body).to include("Quarterly Plan")
    expect(response.body).to include("Beta Project")
    expect(response.body).to include("条件をクリア")
    expect(response.body).not_to include("Operations Guide")
    expect(response.body).not_to include("Beta Hidden Notes")
  end

  it "keeps project bookmark filtering active while filtering recent documents" do
    other_project = create(:project, name: "Other Project")
    later_document = create(:document, project: other_project, title: "Other Checklist", slug: "other-checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project: other_project, title: "Other Guide", slug: "other-guide", visibility_policy: :restricted_external)
    create(:project_membership, project: other_project, user:)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project: other_project, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { project_code: project.code, recent_q: "other" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件「Visible Project」でお気に入りと後で読むを絞り込んでいます。最近見た文書は絞り込み対象外です。")
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Other Checklist")
    expect(response.body).to include("Other Guide")
    expect(response.body).to include("条件をクリア")
  end

  it "keeps saved bookmark filtering active while filtering recent documents" do
    later_document = create(:document, project:, title: "Checklist", slug: "checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project:, title: "Manual Recent Guide", slug: "manual-recent-guide", visibility_policy: :restricted_external)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { bookmark_q: "manual", recent_q: "recent" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Checklist")
    expect(response.body).to include("Manual Recent Guide")
    expect(response.body).to include("条件をクリア")
  end

  it "shows a recent document no-match empty state for unsupported query text" do
    recent_document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: "view", target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { recent_q: "zzz" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する最近見た文書はありません。検索語を変えて探してください。")
    expect(response.body).not_to include("Guide")
    expect(response.body).not_to include("文書を開くと、最近見た文書としてここに表示されます。")
  end

  it "keeps unreadable bookmarked projects out of filter options and results" do
    hidden_project = create(:project, name: "Hidden Project")
    hidden_document = create(:document, project: hidden_project, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :restricted_external)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: hidden_document, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).to include("Visible Project")
    expect(response.body).not_to include("Hidden Manual")
    expect(response.body).not_to include("Hidden Project")
  end

  it "treats invalid project filters as an empty bookmark match without raising" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { project_code: "missing-project" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("指定した案件では保存済みショートカットが見つかりません。最近見た文書は絞り込み対象外です。")
    expect(response.body).to include("案件「missing-project」ではお気に入りが見つかりません。")
    expect(response.body).to include("案件「missing-project」では後で読む文書が見つかりません。")
    expect(response.body).not_to include("Manual")
    expect(response.body.scan("0件").size).to eq(3)
  end

  it "shows actionable empty states with zero counts" do
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body.scan("0件").size).to eq(3)
    expect(response.body).to include("文書画面でお気に入りに追加すると、ここに表示されます。")
    expect(response.body).to include("文書画面で後で読むに追加すると、ここに表示されます。")
    expect(response.body).to include("文書を開くと、最近見た文書としてここに表示されます。")
  end

  it "does not list bookmarks for documents no longer readable by the current user" do
    hidden_document = create(:document, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :restricted_external)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: hidden_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Hidden Manual")
  end

  it "creates a favorite bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(response).to redirect_to(root_path)
  end

  it "creates a read-later bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "read_later"
        }
      }
    end.to change(DocumentBookmark.read_later, :count).by(1)
  end

  it "falls back to favorite when bookmark_type is invalid" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "unexpected"
        }
      }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(user.document_bookmarks.sole).to be_favorite
    expect(response).to redirect_to(root_path)
  end

  it "does not duplicate an existing bookmark" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.not_to change(DocumentBookmark, :count)
  end

  it "moves a read-later bookmark to favorites" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.to change(DocumentBookmark.favorite, :count).by(1)
      .and change(DocumentBookmark.read_later, :count).by(-1)

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("お気に入りへ移しました。")
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :favorite)).to be_present
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :read_later)).to be_nil
  end

  it "moves a read-later bookmark without duplicating an existing favorite" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    favorite_count = DocumentBookmark.favorite.count
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.to change(DocumentBookmark.read_later, :count).by(-1)

    expect(DocumentBookmark.favorite.count).to eq(favorite_count)
    expect(user.document_bookmarks.where(document:, bookmark_type: :favorite).count).to eq(1)
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :read_later)).to be_nil
  end

  it "does not move another user's read-later bookmark" do
    other_user = create(:user, :external, company:)
    bookmark = create(:document_bookmark, user: other_user, document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:not_found)
    expect(bookmark.reload).to be_present
  end

  it "does not move unreadable documents to favorites" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
    expect(bookmark.reload).to be_present
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :favorite)).to be_nil
  end

  it "does not create bookmarks for unreadable documents" do
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "destroys the user's bookmark" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      delete document_bookmark_path(bookmark)
    end.to change(DocumentBookmark, :count).by(-1)
  end

  it "does not destroy another user's bookmark" do
    other_user = create(:user, :external, company:)
    bookmark = create(:document_bookmark, user: other_user, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      delete document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:not_found)
    expect(bookmark.reload).to be_present
  end
end