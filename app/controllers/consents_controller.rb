class ConsentsController < BaseController
  helper_method :safe_return_to

  CONSENT_HISTORY_TARGET_TYPES = %w[global Project Document DocumentFile DocumentVersion].freeze

  before_action :set_target, only: %i[new create]
  before_action :set_timing, only: %i[new create]

  def index
    @consent_history_q = params[:q].to_s.strip
    @consent_history_scope = normalized_consent_scope
    @consent_history_target_type = normalized_consent_history_target_type
    @valid_consent_scopes = ConsentTerm.consent_scopes.keys
    @valid_consent_history_target_types = CONSENT_HISTORY_TARGET_TYPES

    user_consents = current_user.user_consents.includes(:consent_term).preload(:target).order(consented_at: :desc, id: :desc)
    @user_consents_total_count = user_consents.count
    user_consents = user_consents.joins(:consent_term).where(consent_terms: { consent_scope: @consent_history_scope }) if @consent_history_scope.present?
    user_consents = filter_user_consents_by_target_type(user_consents)

    @user_consents = filter_user_consents_by_query(user_consents.to_a)
    @consent_history_filter_active = @consent_history_q.present? || @consent_history_scope.present? || @consent_history_target_type.present?
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

  def normalized_consent_scope
    scope = params[:consent_scope].to_s
    return scope if ConsentTerm.consent_scopes.key?(scope)

    nil
  end

  def normalized_consent_history_target_type
    target_type = params[:target_type].to_s
    return target_type if CONSENT_HISTORY_TARGET_TYPES.include?(target_type)

    nil
  end

  def filter_user_consents_by_target_type(user_consents)
    case @consent_history_target_type
    when "global"
      user_consents.where(target_type: nil)
    when *CONSENT_HISTORY_TARGET_TYPES.excluding("global")
      user_consents.where(target_type: @consent_history_target_type)
    else
      user_consents
    end
  end

  def filter_user_consents_by_query(user_consents)
    return user_consents if @consent_history_q.blank?

    query = @consent_history_q.downcase
    user_consents.select do |consent|
      consent_history_search_text(consent).downcase.include?(query)
    end
  end

  def consent_history_search_text(consent)
    [
      consent.consent_term.title,
      consent.consent_term_version_label,
      consent_target_label_for_filter(consent.target, fallback_type: consent.target_type)
    ].compact.join(" ")
  end

  def consent_target_label_for_filter(target, fallback_type: nil)
    return "全体 global" unless target.present?

    type_name = fallback_type.presence || target.class.name
    type_label = I18n.t("labels.consents.target_type.#{type_name.underscore}", default: type_name)
    target_label = target.try(:name) ||
      target.try(:title) ||
      target.try(:file_name) ||
      target.try(:version_label) ||
      target.to_param

    [type_label, target_label].compact.join(" ")
  end

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
    return projects_path if path.blank?
    return projects_path unless path.start_with?("/") && !path.start_with?("//")
    return projects_path if path.match?(/[[:cntrl:]]/) || path.include?("#")

    path
  end
end
