require "rails_helper"

RSpec.describe "admin project memberships source" do
  let(:form_source) { Rails.root.join("app/views/admin/project_memberships/_form.html.slim").read }
  let(:index_source) { Rails.root.join("app/views/admin/project_memberships/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/project_memberships_helper.rb").read }

  it "uses rails fields kit remote comboboxes for project and user inputs" do
    aggregate_failures do
      expect(form_source).to include('render "shared/error_messages", record: project_membership')
      expect(form_source).to include("form_with model: [:admin, project_membership]")
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
      expect(form_source).to include("form.rfk_select :role,")
      expect(form_source).to include('collection: enum_options_for("project_memberships.role", ProjectMembership.roles.keys)')
      expect(form_source).to include('back_link_to "一覧へ戻る", admin_project_memberships_path')
      expect(form_source).not_to include("form.rfk_select :project_id,")
      expect(form_source).not_to include("form.rfk_select :user_id,")
      expect(form_source).not_to include("collection_select :project_id")
      expect(form_source).not_to include("collection_select :user_id")
    end
  end

  it "wires the compact filters and list table to rails fields kit and table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_project_memberships")
      expect(index_source).to include('details.admin-create-panel open=(@project_membership.errors.any?)')
      expect(index_source).to include('render "form", project_membership: @project_membership')
      expect(index_source).to include("form_with url: admin_project_memberships_path, method: :get")
      expect(index_source).to include("form.rfk_search_field :q,")
      expect(index_source).to include("form.rfk_select :role,")
      expect(index_source).not_to include("search_field_tag :q")
      expect(index_source).to include("render ColumnSettingsComponent.new")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include("scroll_wrapper: true")
      expect(index_source).to include('role: "region"')
      expect(index_source).to include("tabindex: 0")
      expect(index_source).to include("caption.table-caption 案件所属一覧")
      expect(index_source).to include('data-rails-table-preferences-column-key="project"')
      expect(index_source).to include('data-rails-table-preferences-column-key="user"')
      expect(index_source).to include('data-rails-table-preferences-column-key="role"')
      expect(index_source).to include('data-rails-table-preferences-column-key="actions"')
      expect(index_source).to include("project_membership_user_option_label(membership.user)")
      expect(index_source).to include("edit_admin_project_membership_path(membership)")
      expect(index_source).to include("admin_project_membership_path(membership), method: :delete")
      expect(index_source).to include('turbo_confirm: "案件所属を削除しますか？このユーザーは案件へアクセスできなくなります。"')
      expect(index_source).to include('render EmptyStateComponent.new(heading: "案件所属が未登録です"')
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
