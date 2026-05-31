# frozen_string_literal: true

module Admin::ProjectExternalPreviewsHelper
  def external_preview_user_options(users)
    users.map { |user| [external_preview_user_label(user), user.id] }
  end

  def external_preview_user_label(user)
    [
      user.display_name,
      user.email_address,
      user.company&.display_name
    ].compact_blank.join(" / ")
  end
end
