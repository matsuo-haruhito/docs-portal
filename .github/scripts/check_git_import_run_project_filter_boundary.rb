#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

GIT_IMPORT_RUN_PROJECT_FILTER_FILES = {
  routes: GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT.join("config/routes.rb"),
  controller: GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT.join("app/controllers/admin/git_import_runs_controller.rb"),
  view: GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT.join("app/views/admin/git_import_runs/index.html.slim"),
  request_spec: GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT.join("spec/requests/admin_git_import_runs_spec.rb"),
  runbook: GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT.join("docs/Git連携設定と同期失敗確認runbook.md")
}.freeze

GIT_IMPORT_RUN_PROJECT_FILTER_SIGNALS = {
  routes: [
    "resources :git_import_runs, only: [:index] do",
    "get :project_search, on: :collection",
    "get :selected_project, on: :collection"
  ],
  controller: [
    "@selected_project = selected_filter_project",
    "runs.joins(:git_import_source).where(git_import_sources: { project_id: @selected_project_id })",
    "def searchable_projects",
    "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern"
  ],
  view: [
    "form.rfk_combobox :project_id",
    "url: project_search_admin_git_import_runs_path(format: :json)",
    "selected_url: selected_project_admin_git_import_runs_path(format: :json)",
    "label: \"案件\"",
    "適用中の案件"
  ],
  request_spec: [
    "params: { project_id:",
    "filters runs by project",
    "project_search_admin_git_import_runs_path",
    "selected_project_admin_git_import_runs_path"
  ],
  runbook: [
    "`Git同期履歴` に履歴がある場合、画面上部の filter で `状態`、`案件`、`リポジトリ`、`ブランチ`、`取込元パス`、`コミット` を絞り込めます。",
    "`案件` は案件コード・案件名の remote search で、対象 run の `GitImportSource` に紐づく Project を絞り込みます。",
    "`Git同期履歴` の `案件` filter は、run 履歴を案件単位に見返すための条件です。",
    "これは run 履歴の表示範囲だけを変え、Git連携設定一覧、同期 runner、手動同期、GitImportRun の保存内容は変更しません。pagination、CSV export は current support ではありません"
  ]
}.freeze

errors = []

GIT_IMPORT_RUN_PROJECT_FILTER_FILES.each do |label, path|
  errors << "#{label}: missing file #{path}" unless path.file?
end

if errors.empty?
  GIT_IMPORT_RUN_PROJECT_FILTER_FILES.each do |label, path|
    content = path.read
    GIT_IMPORT_RUN_PROJECT_FILTER_SIGNALS.fetch(label).each do |expected_text|
      next if content.include?(expected_text)

      errors << "#{path.relative_path_from(GIT_IMPORT_RUN_PROJECT_FILTER_REPO_ROOT)}: missing git import run project filter signal: #{expected_text.inspect}"
    end
  end
end

if errors.any?
  warn "Git import run project filter boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Git import run project filter boundary guard passed."
