require "rails_helper"

RSpec.describe "Admin project memberships", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_membership_select_names
    parsed_html.css('select[name^="project_membership["]').map { |node| node["name"] }
  end

  def membership_rows
    parsed_html.css("table tbody tr")
  end

  def membership_row_texts
    membership_rows.map { _1.text.squish }
  end

  def column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map { _1["data-rails-table-preferences-column-key"] }.uniq
  end

  def disabled_pagination_labels
    parsed_html.css('[aria-disabled="true"]').map { _1.text.squish }
  end

  def create_membership(number)
    project = create(:project, code: format("PM-%03d", number), name: "Membership Project #{number}")
    user = create(:user, :external, name: "Member #{number}", email_address: format("member%03d@example.com", number))

    create(:project_membership, project:, user:, role: :viewer)
  end

  it "renders the project membership select fields on initial load and invalid rerender" do
    sign_in_as(admin_user)

    get admin_project_memberships_path

    expect(response).to have_http_status(:ok)
    expect(project_membership_select_names).to include(
      "project_membership[project_id]",
      "project_membership[user_id]",
      "project_membership[role]"
    )

    post admin_project_memberships_path, params: {
      project_membership: {
        project_id: "",
        user_id: "",
        role: "viewer"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(project_membership_select_names).to include(
      "project_membership[project_id]",
      "project_membership[user_id]",
      "project_membership[role]"
    )
  end

  it "shows the first bounded page while preserving table preferences metadata" do
    (1..26).each { create_membership(_1) }

    sign_in_as(admin_user)

    get admin_project_memberships_path

    expect(response).to have_http_status(:ok)
    expect(membership_rows.size).to eq(Admin::ProjectMembershipsController::DEFAULT_PAGE_SIZE)
    expect(page_text).to include(
      "表示中: 1-25件 / 全26件",
      "1ページ25件",
      "Page 1 / 2",
      "先頭ページ",
      "案件所属一覧の表示設定",
      "表示設定は列の表示切り替え用です"
    )
    expect(disabled_pagination_labels).to include("前へ（先頭）")
    expect(membership_row_texts).to include(a_string_including("Membership Project 1", "PM-001", "member001@example.com"))
    expect(membership_row_texts).to include(a_string_including("Membership Project 25", "PM-025", "member025@example.com"))
    expect(membership_row_texts).not_to include(a_string_including("PM-026"))
    expect(column_keys).to include("project", "user", "role", "actions")
    expect(parsed_html.at_css(%(a[href="#{admin_project_memberships_path(page: 2, per_page: 25)}"]))).to be_present
  end

  it "explains disabled pagination when one page contains all memberships" do
    (1..5).each { create_membership(_1) }

    sign_in_as(admin_user)

    get admin_project_memberships_path

    expect(response).to have_http_status(:ok)
    expect(membership_rows.size).to eq(5)
    expect(page_text).to include("表示中: 1-5件 / 全5件", "1ページ25件", "Page 1 / 1", "1ページのみ")
    expect(disabled_pagination_labels).to include("前へ（先頭）", "次へ（最終）")
  end

  it "keeps project code and user email ordering on later pages" do
    (1..26).each { create_membership(_1) }

    sign_in_as(admin_user)

    get admin_project_memberships_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(membership_rows.size).to eq(1)
    expect(page_text).to include("表示中: 26-26件 / 全26件", "1ページ25件", "Page 2 / 2", "最終ページ")
    expect(disabled_pagination_labels).to include("次へ（最終）")
    expect(membership_row_texts).to contain_exactly(a_string_including("Membership Project 26", "PM-026", "member026@example.com"))
    expect(parsed_html.at_css(%(a[href="#{admin_project_memberships_path(page: 1, per_page: 25)}"]))).to be_present
  end

  it "bounds oversized and invalid per_page values" do
    (1..105).each { create_membership(_1) }

    sign_in_as(admin_user)

    get admin_project_memberships_path, params: { per_page: 1_000 }

    expect(response).to have_http_status(:ok)
    expect(membership_rows.size).to eq(Admin::ProjectMembershipsController::MAX_PAGE_SIZE)
    expect(page_text).to include("表示中: 1-100件 / 全105件", "1ページ100件", "Page 1 / 2")
    expect(membership_row_texts).not_to include(a_string_including("PM-101"))

    get admin_project_memberships_path, params: { per_page: "invalid", page: -3 }

    expect(response).to have_http_status(:ok)
    expect(membership_rows.size).to eq(Admin::ProjectMembershipsController::DEFAULT_PAGE_SIZE)
    expect(page_text).to include("表示中: 1-25件 / 全105件", "1ページ25件", "Page 1 / 5")
  end

  it "keeps invalid create rerenders bounded with validation errors" do
    (1..5).each { create_membership(_1) }

    sign_in_as(admin_user)

    post admin_project_memberships_path,
         params: {
           per_page: 3,
           project_membership: { project_id: "", user_id: "", role: "viewer" }
         }

    expect(response).to have_http_status(:unprocessable_content)
    expect(membership_rows.size).to eq(3)
    expect(page_text).to include("表示中: 1-3件 / 全5件", "1ページ3件", "新規登録", "案件所属一覧の表示設定")
    expect(membership_row_texts).to include(a_string_including("PM-001"), a_string_including("PM-003"))
    expect(membership_row_texts).not_to include(a_string_including("PM-004"))
    expect(column_keys).to include("project", "user", "role", "actions")
  end

  it "uses public_id-based action links on the index" do
    membership = create(:project_membership)

    sign_in_as(admin_user)

    get admin_project_memberships_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_project_membership_path(membership.public_id))
    expect(response.body).to include(admin_project_membership_path(membership.public_id))
    expect(response.body).not_to include(edit_admin_project_membership_path(membership.id))
    expect(response.body).not_to include(admin_project_membership_path(membership.id))
    expect(admin_project_membership_path(membership)).to eq("/admin/project_memberships/#{membership.public_id}")
    expect(edit_admin_project_membership_path(membership)).to eq("/admin/project_memberships/#{membership.public_id}/edit")
  end

  it "finds the edit page by public_id" do
    membership = create(:project_membership)

    sign_in_as(admin_user)

    get edit_admin_project_membership_path(membership.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件所属編集")
  end

  it "rejects numeric ids on the edit page" do
    membership = create(:project_membership)

    sign_in_as(admin_user)

    get edit_admin_project_membership_path(membership.id)

    expect(response).to have_http_status(:not_found)
  end

  it "updates a project membership via public_id and keeps the index redirect" do
    membership = create(:project_membership, role: :viewer)

    sign_in_as(admin_user)

    patch admin_project_membership_path(membership.public_id), params: {
      project_membership: {
        project_id: membership.project_id,
        user_id: membership.user_id,
        role: :owner
      }
    }

    expect(response).to redirect_to(admin_project_memberships_path)
    expect(membership.reload.role).to eq("owner")
  end

  it "rejects numeric ids on update" do
    membership = create(:project_membership, role: :viewer)

    sign_in_as(admin_user)

    patch admin_project_membership_path(membership.id), params: {
      project_membership: {
        project_id: membership.project_id,
        user_id: membership.user_id,
        role: :owner
      }
    }

    expect(response).to have_http_status(:not_found)
    expect(membership.reload.role).to eq("viewer")
  end

  it "destroys a project membership via public_id and keeps the index redirect" do
    membership = create(:project_membership)

    sign_in_as(admin_user)

    expect do
      delete admin_project_membership_path(membership.public_id)
    end.to change(ProjectMembership, :count).by(-1)

    expect(response).to redirect_to(admin_project_memberships_path)
  end

  it "rejects numeric ids on destroy" do
    membership = create(:project_membership)

    sign_in_as(admin_user)

    delete admin_project_membership_path(membership.id)

    expect(response).to have_http_status(:not_found)
    expect(ProjectMembership.exists?(membership.id)).to be(true)
  end
end