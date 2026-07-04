class Admin::DocumentsController < Admin::BaseController
  BULK_EDIT_CANDIDATE_LIMIT = 50
  LIFECYCLE_HANDOFF_LIMIT = 50
  LIFECYCLE_DUE_SOON_WINDOW = 30.days
  DOCUMENT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  before_action :require_admin_only!
  before_action :block_document_mutation_during_maintenance, only: %i[create update destroy archive restore]
  before_action :set_document, only: %i[edit update destroy archive restore]

  helper_method :document_return_to_path

  def index
    load_document_index_state
    @document = Document.new(category: :spec, document_kind: :markdown, visibility_policy: :internal_only)
  end

  def lifecycle_handoff
    @filters = document_filter_params
    document_scope = filtered_documents
    total_count = document_scope.unscope(:order).count
    candidates = document_scope
      .includes(:project)
      .order("projects.code", :title)
      .limit(LIFECYCLE_HANDOFF_LIMIT)
      .map { |document| lifecycle_handoff_candidate(document) }

    render json: {
      current_filter: compact_filters(@filters),
      total_count:,
      limit: LIFECYCLE_HANDOFF_LIMIT,
      truncated: total_count > LIFECYCLE_HANDOFF_LIMIT,
      note: lifecycle_handoff_note(total_count),
      runbook_path: "docs/文書マスタ運用runbook.md",
      candidates:
    }
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to admin_documents_path, notice: "文書を登録しました。"
    else
      load_document_index_state
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to document_return_to_path, notice: "文書を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy!
    redirect_to document_return_to_path, notice: "文書を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to document_return_to_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to document_return_to_path, alert: "関連データがあるため削除できません。"
  end

  def archive
    @document.archive!(
      actor: current_user,
      retention_until: params[:retention_until],
      discard_candidate_at: params[:discard_candidate_at]
    )
    redirect_to document_return_to_path, notice: "文書をアーカイブしました。"
  end

  def restore
    @document.restore!(actor: current_user)
    redirect_to document_return_to_path, notice: "文書を復元しました。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def block_document_mutation_during_maintenance
    return unless read_only_maintenance_mode?

    redirect_to admin_documents_path, alert: maintenance_document_message
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_document_message
    "メンテナンス中のため文書マスタの登録・編集・アーカイブ・復元・削除は停止しています。文書マスタ一覧、検索、lifecycle handoff、公開側文書の確認は継続できます。"
  end

  def set_document
    @document = Document.find_by!(public_id: params[:public_id])
  end

  def document_return_to_path
    safe_return_to_path(admin_documents_path)
  end

  def load_document_index_state
    @filters = document_filter_params
    document_scope = filtered_documents
    @documents_filtered_count = document_scope.count
    ordered_documents = document_scope.includes(:project, :latest_version, :archived_by_user, :document_versions).order("projects.code", :title)
    @documents, @documents_pagination = paginate_admin_list(ordered_documents, @documents_filtered_count)
    @document_page_params = document_page_params
    load_bulk_edit_candidate_state(document_scope)
  end

  def document_params
    params.require(:document).permit(:project_id, :title, :slug, :category, :document_kind, :visibility_policy, :retention_until, :discard_candidate_at)
  end

  def document_filter_params
    params.to_unsafe_h.symbolize_keys.slice(:q, :category, :document_kind, :visibility_policy, :archived, :retention, :discard).tap do |filters|
      filters[:q] = normalize_document_search_query(filters[:q])
    end
  end

  def document_page_params
    page_params = @filters.transform_keys(&:to_s)
    page_params["per_page"] = @documents_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def normalize_document_search_query(value)
    value.to_s.strip.first(DOCUMENT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_project_search_query(value)
    value.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.admin_document_project_option_label(project) }
  end

  def load_bulk_edit_candidate_state(document_scope)
    @bulk_edit_candidate_limit = BULK_EDIT_CANDIDATE_LIMIT
    @bulk_edit_candidate_count = @documents_filtered_count
    @bulk_edit_candidate_ids = []
    @bulk_archive_candidate_count = document_scope.active_only.count
    @bulk_restore_candidate_count = document_scope.archived_only.count
    @bulk_archive_candidate_ids = []
    @bulk_restore_candidate_ids = []
    return if @bulk_edit_candidate_count.zero? || @bulk_edit_candidate_count > @bulk_edit_candidate_limit

    ordered_scope = document_scope.includes(:project).order("projects.code", :title)
    @bulk_edit_candidate_ids = ordered_scope.to_a.map(&:id)
    @bulk_archive_candidate_ids = ordered_scope.active_only.to_a.map(&:id) if @bulk_archive_candidate_count.positive?
    @bulk_restore_candidate_ids = ordered_scope.archived_only.to_a.map(&:id) if @bulk_restore_candidate_count.positive?
  end

  def filtered_documents
    scope = Document.joins(:project)
    scope = apply_keyword_filter(scope)
    scope = apply_enum_filter(scope, :category, Document.categories)
    scope = apply_enum_filter(scope, :document_kind, Document.document_kinds)
    scope = apply_enum_filter(scope, :visibility_policy, Document.visibility_policies)
    scope = apply_archived_filter(scope)
    scope = apply_retention_filter(scope)
    scope = apply_discard_filter(scope)
    scope.distinct
  end

  def apply_keyword_filter(scope)
    keyword = @filters[:q].to_s
    return scope if keyword.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
    scope.where(
      "documents.title ILIKE :pattern OR documents.slug ILIKE :pattern OR projects.name ILIKE :pattern OR projects.code ILIKE :pattern",
      pattern: pattern
    )
  end

  def apply_enum_filter(scope, key, enum_values)
    value = @filters[key].to_s
    return scope if value.blank? || !enum_values.key?(value)

    scope.where(key => value)
  end

  def apply_archived_filter(scope)
    case @filters[:archived].to_s
    when "active"
      scope.active_only
    when "archived"
      scope.archived_only
    else
      scope
    end
  end

  def apply_retention_filter(scope)
    case @filters[:retention].to_s
    when "set"
      scope.where.not(retention_until: nil)
    when "missing"
      scope.where(retention_until: nil)
    when "due"
      scope.where.not(retention_until: nil).where(retention_until: ..Time.current)
    when "due_soon"
      apply_due_soon_filter(scope, :retention_until)
    else
      scope
    end
  end

  def apply_discard_filter(scope)
    case @filters[:discard].to_s
    when "set"
      scope.where.not(discard_candidate_at: nil)
    when "missing"
      scope.where(discard_candidate_at: nil)
    when "due"
      scope.where.not(discard_candidate_at: nil).where(discard_candidate_at: ..Time.current)
    when "due_soon"
      apply_due_soon_filter(scope, :discard_candidate_at)
    else
      scope
    end
  end

  def apply_due_soon_filter(scope, column)
    now = Time.current
    scope.where.not(column => nil).where(column => now..LIFECYCLE_DUE_SOON_WINDOW.from_now)
  end

  def lifecycle_handoff_candidate(document)
    {
      public_id: document.public_id,
      project_code: document.project.code,
      project_name: document.project.name,
      title: document.title,
      slug: document.slug,
      status: document.archived? ? "archived" : "active",
      review_focus: lifecycle_review_focus(document),
      retention_until: document.retention_until&.iso8601,
      discard_candidate_at: document.discard_candidate_at&.iso8601,
      admin_edit_path: edit_admin_document_path(document.public_id),
      public_document_path: project_document_path(document.project, document.slug),
      note: lifecycle_candidate_note(document)
    }
  end

  def lifecycle_review_focus(document)
    document.archived? ? "restore_candidate_review" : "archive_candidate_review"
  end

  def lifecycle_candidate_note(document)
    if document.archived?
      "アーカイブ済み文書です。復元検討候補として確認してください。"
    else
      "有効な文書です。archive / restore / discard の実行確定ではなく、行単位判断の検討候補として確認してください。"
    end
  end

  def lifecycle_handoff_note(total_count)
    if total_count.zero?
      "現在条件で lifecycle handoff 対象はありません。正常保証、全期間0件、自動削除不要を意味しません。"
    else
      "現在条件に一致する文書マスタの read-only handoff です。archive / restore / discard / delete は実行しません。"
    end
  end

  def compact_filters(filters)
    filters.reject { |_key, value| value.blank? }
  end
end
