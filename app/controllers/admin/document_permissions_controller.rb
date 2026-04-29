class Admin::DocumentPermissionsController < Admin::BaseController
  before_action :set_document_permission, only: %i[edit update destroy]
  before_action :load_master_options, only: %i[index create edit update]

  def index
    @document_permissions = DocumentPermission.joins(:document).includes(:document, :company, :user).order("documents.title")
    @document_permission = DocumentPermission.new(access_level: :view)
  end

  def create
    @document_permission = DocumentPermission.new(document_permission_params)

    if @document_permission.save
      redirect_to admin_document_permissions_path, notice: "文書権限を登録しました。"
    else
      @document_permissions = DocumentPermission.joins(:document).includes(:document, :company, :user).order("documents.title")
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document_permission.update(document_permission_params)
      redirect_to admin_document_permissions_path, notice: "文書権限を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_permission.destroy!
    redirect_to admin_document_permissions_path, notice: "文書権限を削除しました。"
  end

  private

  def set_document_permission
    @document_permission = DocumentPermission.find(params[:id])
  end

  def load_master_options
    @documents = Document.includes(:project).order(:title)
    @companies = Company.order(:code)
    @users = User.order(:email_address)
  end

  def document_permission_params
    permitted = params.require(:document_permission).permit(:document_id, :company_id, :user_id, :access_level)
    permitted[:company_id] = nil if permitted[:company_id].blank?
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end
end
