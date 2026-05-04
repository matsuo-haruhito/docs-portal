class ConsentRequirementChecker
  Result = Data.define(:required_terms, :missing_terms) do
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
      missing_terms: terms.reject { consented_to?(_1) }
    )
  end

  private

  attr_reader :user, :target, :timing

  def required_terms
    scope = ConsentTerm.active_only
    scope = scope.where(requirement_timing: timing) if timing.present?
    scope.select { applicable_to_target?(_1) }
  end

  def applicable_to_target?(term)
    return true if term.global?
    return false if target.blank?

    case target
    when Project
      term.project?
    when Document
      term.document? || term.project?
    when DocumentFile
      term.download? || term.document? || term.project?
    else
      false
    end
  end

  def consented_to?(term)
    consent_scope = UserConsent.where(user:, consent_term: term)
    return consent_scope.exists?(target: nil) if term.global?

    target_candidates_for(term).any? { consent_scope.exists?(target: _1) }
  end

  def target_candidates_for(term)
    return [] if target.blank?

    case target
    when Project
      [target]
    when Document
      term.project? ? [target.project] : [target]
    when DocumentFile
      document = target.document_version.document
      return [document.project] if term.project?
      return [document] if term.document?

      [target]
    else
      []
    end
  end
end
