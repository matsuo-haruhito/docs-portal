require "rails_helper"

RSpec.describe "admin git import admin UI source" do
  let(:form_source) { Rails.root.join("app/views/admin/git_import_sources/_form.html.slim").read }
  let(:sources_index_source) { Rails.root.join("app/views/admin/git_import_sources/index.html.slim").read }
  let(:runs_index_source) { Rails.root.join("app/views/admin/git_import_runs/index.html.slim").read }
  let(:sources_helper_source) { Rails.root.join("app/helpers/admin/git_import_sources_helper.rb").read }
  let(:runs_helper_source) { Rails.root.join("app/helpers/admin/git_import_runs_helper.rb").read }

  it "uses rails fields kit for git import source project selection" do
    aggregate_failures do
      expect(form_source).to include("form.rfk_select :project_id,")
      expect(form_source).to include("git_import_source_project_option_label")
      expect(form_source).to include('label: "案件"')
      expect(form_source).to include('placeholder: "案件を選択"')
      expect(form_source).not_to include("form.collection_select :project_id")
    end
  end

  it "keeps git import auth and external sync boundary copy explicit" do
    aggregate_failures do
      expect(form_source).to include("GitHub App は本命、Fine-grained PAT は検証用、認証なしは公開リポジトリ用です。")
      expect(form_source).to include("同期元設定、run履歴、manifest化、削除候補")
      expect(form_source).to include("Google Drive / SharePoint 本体や自動同期はこの画面では追加しません。")
      expect(form_source).to include("認証なしは公開リポジトリの clone に限定して使います。")
    end
  end

  it "wires the source index to rails table preferences" do
    aggregate_failures do
      expect(sources_index_source).to include("table_preferences_editor")
      expect(sources_index_source).to include("table_preferences_table_tag")
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="project"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="repository"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="branch_path"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="auth_type"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="last_synced"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="enabled"')
      expect(sources_index_source).to include('data-rails-table-preferences-column-key="actions"')
      expect(sources_index_source).to include("sync_admin_git_import_source_path(source)")
    end
  end

  it "wires the run index to rails table preferences with project visibility" do
    aggregate_failures do
      expect(runs_index_source).to include("table_preferences_editor")
      expect(runs_index_source).to include("table_preferences_table_tag")
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="created_at"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="project"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="repository"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="branch_path"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="commit_sha"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="status"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="summary"')
      expect(runs_index_source).to include('data-rails-table-preferences-column-key="error_message"')
      expect(runs_index_source).to include("run.git_import_source&.project")
      expect(runs_index_source).to include("git_import_run_summary_lines(run)")
      expect(runs_index_source).to include("raw summary_json")
    end
  end

  it "defines helper metadata for source and run tables" do
    aggregate_failures do
      expect(sources_helper_source).to include("def git_import_source_table_columns")
      expect(sources_helper_source).to include("table_preferences_column(:project")
      expect(sources_helper_source).to include("table_preferences_column(:repository")
      expect(sources_helper_source).to include("table_preferences_column(:last_synced")
      expect(sources_helper_source).to include("def git_import_source_project_option_label(project)")
      expect(sources_helper_source).to include('compact_blank.join(" / ")')
      expect(runs_helper_source).to include("def git_import_run_table_columns")
      expect(runs_helper_source).to include("table_preferences_column(:project")
      expect(runs_helper_source).to include("table_preferences_column(:status")
      expect(runs_helper_source).to include("table_preferences_column(:error_message")
      expect(runs_helper_source).to include("def git_import_run_summary_lines(run)")
      expect(runs_helper_source).to include("削除候補")
    end
  end
end
