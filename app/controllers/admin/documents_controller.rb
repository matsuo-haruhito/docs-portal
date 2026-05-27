class Admin::DocumentsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document, only: %i[edit update destroy archive restore]
  before_action :load_projects, only: %i[index create edit update]

  def index
    @filters = document_filter_params
    @documents = filtered_documents.includes(:project, :latest_version, :archived_by_user).order("projects.code", :title)
    @document = Document.new(category: :spec, document_kind: :markdown, visibility_policy: :internal_only)
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to admin_documents_path, notice: "文書を登録しました。"
    else
      @filters = document_filter_params
      @documents = filtered_documents.includes(:project, :latest_version, :archived_by_user).order("projects.code", :title)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to admin_documents_path, notice: "文書を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy!
    redirect_to admin_documents_path, notice: "文書を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_documents_path, alert: "関連データがあるため削除できません。"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to admin_documents_path, alert: "関連データがあるため削除できません。"
  end

  def archive
    @document.archive!(
      actor: current_user,
      retention_until: params[:retention_until],
      discard_candidate_at: params[:discard_candidate_at]
    )
    redirect_to admin_documents_path, notice: "文書をアーカイブしました。"
  end

  def restore
    @document.restore!(actor: current_user)
    redirect_to admin_documents_path, notice: "文書を復元しました。"
  end

  private

  def set_document
    @document = Document.find_by!(public_id: params[:public_id])
  end

  def load_projects
    @projects = Project.order(:code)
  end

  def document_params
    params.require(:document).permit(:project_id, :title, :slug, :category, :document_kind, :visibility_policy, :retention_until, :discard_candidate_at)
  end

  def document_filter_params
    params.to_unsafe_h.symbolize_keys.slice(:q, :category, :document_kind, :visibility_policy, :archived, :retention, :discard)
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
    keyword = @filters[:q].to_s.strip
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
    else
      scope
    end
  end
end