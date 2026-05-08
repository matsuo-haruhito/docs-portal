module NotificationPublishing
  class RecipientResolver
    def initialize(document:)
      @document = document
    end

    def call
      internal_ids = User.active_only.where(user_type: User.user_types[:internal]).pluck(:id)
      project_member_ids = ProjectMembership.where(project_id: document.project_id).pluck(:user_id)

      User.active_only
        .where(id: (internal_ids + project_member_ids).uniq)
        .select { document.viewable_by?(_1) }
    end

    private

    attr_reader :document
  end
end
