class ConsentsController < BaseController
  helper_method :safe_return_to

  before_action :set_target, only: %i[new create]
  before_action :set_timing, only: %i[new create]

  def index
    @user_consents = current_user.user_consents.includes(:consent_term, :target).order(consented_at: :desc, id: :desc)
    @active_terms = ConsentTerm.active_only.order(:title, :version_label)
  end

  def new
    @result = ConsentRequirementChecker.new(user: current_user, target: @target, timing: @timing).call
    redirect_to safe_return_to, notice: "必要な同意は完了しています。" if @result.satisfied?
  end

  def create
    result = ConsentRequirementChecker.new(user: current_user, target: @target, timing: @timing).call
    result.missing_terms.each do |term|
      UserConsent.find_or_create_by!(
        user: current_user,
        consent_term: term,
        target: target_for(term, result),
        consent_term_version_label: term.version_label
      ) do |consent|
        consent.ip_address = request.remote_ip
        consent.user_agent = request.user_agent
      end
    end

    redirect_to safe_return_to, notice: "注意事項に同意しました。"
  end

  private

  def set_target
    @target = find_target(params[:target_type], params[:target_public_id])
  end

  def set_timing
    @timing = params[:timing].presence || "first_view"
  end

  def target_for(term, result)
    term.global? ? nil : result.target
  end

  def find_target(target_type, target_public_id)
    case target_type
    when "Project"
      Project.find_by!(public_id: target_public_id)
    when "Document"
      Document.find_by!(public_id: target_public_id)
    when "DocumentFile"
      DocumentFile.find_by!(public_id: target_public_id)
    when "DocumentVersion"
      DocumentVersion.find_by!(public_id: target_public_id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def safe_return_to
    path = params[:return_to].to_s
    return projects_path if path.blank? || path.start_with?("//") || path.match?(%r{\Ahttps?://})

    path
  end
end
