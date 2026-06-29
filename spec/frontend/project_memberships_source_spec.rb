require "rails_helper"

RSpec.describe "admin project memberships source" do
  let(:form_source) { Rails.root.join("app/views/admin/project_memberships/_form.html.erb").read }
  let(:index_source) { Rails.root.join("app/views/admin/project_memberships/index.html.erb").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/project_memberships_helper.rb").read }

  it "uses rails fields kit remote comboboxes for project and user inputs" do
    aggregate_failures do
      expect(form_source).to include("form.rfk_combobox :project_id,")
      expect(form_source).to include("collection: []")
      expect(form_source).to include("selected: project_membership_project_selected_option(project_membership.project)")
      expect(form_source).to include("url: project_search_admin_project_memberships_path(format: :json)")
      expect(form_source).to include("selected_url: selected_project_admin_project_memberships_path(format: :json)")
      expect(form_source).to include("max_options: Admin::ProjectMembershipsController::PROJECT_SEARCH_LIMIT")
      expect(form_source).to include('label: "案件"')
      expect(form_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(form_source).to include("form.rfk_combobox :user_id,")
      expect(form_source).to include("selected: project_membership_user_selected_option(project_membership.user)")
      expect(form_source).to include("url: user_search_admin_project_memberships_path(format: :json)")
      expect(form_source).to include("selected_url: selected_user_admin_project_memberships_path(format: :json)")
      expect(form_source).to include("max_options: Admin::ProjectMembershipsController::USER_SEARCH_LIMIT")
      expect(form_source).to include('label: "ユーザー"')
      expect(form_source).to include('placeholder: "ユーザー名・メールアドレスで検索"')
      expect(form_source).not_to include("form.rfk_select :project_id,")
      expect(form_source).not_to include("form.rfk_select :user_id,")
      expect(form_source).not_to include("collection_select :project_id")
      expect(form_source).not_to include("collection_select :user_id")
    end
  end

  it "wires the index to rails table preferences columns" do
    aggregate_failures do
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('data-rails-table-preferences-column-key="project"')
      expect(index_source).to include('data-rails-table-preferences-column-key="user"')
      expect(index_source).to include('data-rails-table-preferences-column-key="role"')
      expect(index_source).to include('data-rails-table-preferences-column-key="actions"')
      expect(index_source).to include("project_membership_user_option_label(membership.user)")
    end
  end

  it "defines helper metadata for table columns and option labels" do
    aggregate_failures do
      expect(helper_source).to include("def project_membership_table_columns")
      expect(helper_source).to include("table_preferences_column(:project")
      expect(helper_source).to include("table_preferences_column(:user")
      expect(helper_source).to include("table_preferences_column(:role")
      expect(helper_source).to include("def project_membership_project_option_label(project)")
      expect(helper_source).to include("def project_membership_project_selected_option(project)")
      expect(helper_source).to include("def project_membership_user_option_label(user)")
      expect(helper_source).to include("def project_membership_user_selected_option(user)")
      expect(helper_source).to include('compact_blank.join(" / ")')
    end
  end
end
