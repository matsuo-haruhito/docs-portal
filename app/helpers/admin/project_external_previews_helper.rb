# frozen_string_literal: true

module Admin::ProjectExternalPreviewsHelper
  def external_preview_user_options(users)
    users.map { |user| [external_preview_user_label(user), user.id] }
  end

  def external_preview_company_options(companies)
    companies.map { |company| [external_preview_company_label(company), company.id] }
  end

  def external_preview_user_label(user)
    [
      user.display_name,
      user.email_address,
      user.company&.display_name
    ].compact_blank.join(" / ")
  end

  def external_preview_company_label(company)
    [company.display_name, company.domain].compact_blank.join(" / ")
  end
end
