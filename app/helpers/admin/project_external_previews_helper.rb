# frozen_string_literal: true

module Admin::ProjectExternalPreviewsHelper
  def external_preview_user_options(users)
    users.map { |user| [external_preview_user_label(user), user.id] }
  end

  def external_preview_user_selected_option(user)
    return if user.blank?

    { value: user.id, text: external_preview_user_label(user) }
  end

  def external_preview_user_label(user)
    [
      user.display_name,
      user.email_address,
      user.company&.display_name
    ].compact_blank.join(" / ")
  end

  def external_preview_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: external_preview_company_label(company) }
  end

  def external_preview_company_label(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?
    label
  end
end