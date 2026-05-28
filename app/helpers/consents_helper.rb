module ConsentsHelper
  def consent_target_display(consent)
    return "全体" unless consent.target.present?

    type_label = t("labels.consents.target_type.#{consent.target_type.underscore}", default: consent.target_type)
    target_label = consent.target.try(:name) ||
      consent.target.try(:title) ||
      consent.target.try(:file_name) ||
      consent.target.try(:version_label) ||
      consent.target.to_param

    [type_label, target_label].compact.join(" / ")
  end
end
