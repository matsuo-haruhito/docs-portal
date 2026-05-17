module ApplicationHelper
  def page_title(*parts)
    content_for :title, parts.compact.join(" | ")
  end

  def localized_label(scope, value, **interpolations)
    value = value.to_s
    translation_options = interpolations.except(:default)
    I18n.t("labels.#{scope}.#{value}", **translation_options, default: value)
  end

  def enum_options_for(scope, values)
    values.map { |value| [localized_label(scope, value), value] }
  end

  def user_type_label(user_or_value)
    value = user_or_value.respond_to?(:user_type) ? user_or_value.user_type : user_or_value
    localized_label("users.user_type", value)
  end

  def project_membership_role_label(membership_or_value)
    value = membership_or_value.respond_to?(:role) ? membership_or_value.role : membership_or_value
    localized_label("project_memberships.role", value)
  end

  def document_set_type_label(document_set_or_value)
    value = document_set_or_value.respond_to?(:set_type) ? document_set_or_value.set_type : document_set_or_value
    localized_label("document_sets.set_type", value)
  end

  def document_set_visibility_policy_label(document_set_or_value)
    value = document_set_or_value.respond_to?(:visibility_policy) ? document_set_or_value.visibility_policy : document_or_value
    localized_label("document_sets.visibility_policy", value)
  end
end
