module ConsentsHelper
  def consent_scope_label(term)
    t("labels.consent_terms.consent_scope.#{term.consent_scope}", default: term.consent_scope.to_s)
  end

  def consent_target_display(consent)
    consent_target_label(consent.target, fallback_type: consent.target_type)
  end

  def consent_target_label(target, fallback_type: nil)
    return "全体" unless target.present?

    type_name = fallback_type.presence || target.class.name
    type_label = t("labels.consents.target_type.#{type_name.underscore}", default: type_name)
    target_label = target.try(:name) ||
      target.try(:title) ||
      target.try(:file_name) ||
      target.try(:version_label) ||
      target.to_param

    [type_label, target_label].compact.join(" / ")
  end

  def consent_history_target_type_label(target_type)
    return "全体" if target_type == "global"

    t("labels.consents.target_type.#{target_type.underscore}", default: target_type)
  end
end
