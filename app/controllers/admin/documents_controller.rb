class Admin::DocumentsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document, only: %i[edit update destroy archive restore]
  before_action :load_projects, only: %i[index create edit update]

  def index
    @documents = Document.joins(:project).includes(:project, :latest_version, :archived_by_user).order("projects.code", :title)
    @document = Document.new(category: :spec, document_kind: :markdown, visibility_policy: :internal_only)
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to admin_documents_path, notice: "文書を登録しました。"
    else
      @documents = Document.joins(:project).includes(:project, :latest_version, :archived_by_user).order("projects.code", :title)
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
    @document = Document.find_by!(id: params[:id])
  end

  def load_projects
    @projects = Project.order(:code)
  end

  def document_params
    params.require(:document).permit(:project_id, :title, :slug, :category, :document_kind, :visibility_policy, :retention_until, :discard_candidate_at)
  end
end
