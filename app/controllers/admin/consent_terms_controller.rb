class Admin::ConsentTermsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_consent_term, only: %i[edit update destroy]

  def index
    @consent_terms = ConsentTerm.order(:title, :version_label)
    @consent_term = ConsentTerm.new(active: true, consent_scope: :project, requirement_timing: :first_view)
  end

  def create
    @consent_term = ConsentTerm.new(consent_term_params)

    if @consent_term.save
      redirect_to admin_consent_terms_path, notice: "同意文面を登録しました。"
    else
      @consent_terms = ConsentTerm.order(:title, :version_label)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @consent_term.update(consent_term_params)
      redirect_to admin_consent_terms_path, notice: "同意文面を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @consent_term.destroy!
    redirect_to admin_consent_terms_path, notice: "同意文面を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    redirect_to admin_consent_terms_path, alert: "関連データがあるため削除できません。無効化してください。"
  end

  private

  def set_consent_term
    @consent_term = ConsentTerm.find_by!(public_id: params[:public_id])
  end

  def consent_term_params
    params.require(:consent_term).permit(:title, :body, :version_label, :consent_scope, :requirement_timing, :active)
  end
end
