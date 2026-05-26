require "rails_helper"

RSpec.describe "Admin project memberships", type: :request do
  let(:admin_user) { create(:user, :internal) }

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