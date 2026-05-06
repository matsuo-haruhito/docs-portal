class ConsentRequirementChecker
  Result = Data.define(:required_terms, :missing_terms, :target) do
    def required?
      required_terms.any?
    end

    def satisfied?
      missing_terms.empty?
    end
  end

  def initialize(user:, target: nil, timing: nil)
    @user = user
    @target = target
    @timing = timing
  end

  def call
    terms = required_terms
    Result.new(
      required_terms: terms,
      missing_terms: terms.reject { consented_to?(_1) },
      target: consent_target
    )
  end

  private

  attr_reader :user, :target, :timing

  def required_terms
    (global_required_terms + project_required_terms).uniq
  end

  def project_required_terms
    return [] if project_target.blank?

    settings = project_target.project_consent_settings.enabled_only.includes(:consent_term)
    settings = settings.where(required_on: required_on_for_timing) if required_on_for_timing.present?
    settings.map(&:consent_term).select(&:active?).uniq
  end

  def global_required_terms
    scope = ConsentTerm.active_only.global
    scope = scope.where(requirement_timing: timing) if timing.present?
    scope.to_a
  end

  def required_on_for_timing
    case timing&.to_s
    when "first_view", "first_access"
      :first_access
    when "every_download", "download"
      :download
    end
  end

  def consented_to?(term)
    consent_scope = UserConsent.where(user:, consent_term: term, consent_term_version_label: term.version_label)
    return consent_scope.exists?(target: nil) if term.global?

    consent_scope.exists?(target: consent_target)
  end

  def project_target
    case target
    when Project
      target
    when Document
      target.project
    when DocumentFile
      target.document_version.document.project
    when DocumentVersion
      target.document.project
    end
  end

  def consent_target
    project_target || target
  end
end
