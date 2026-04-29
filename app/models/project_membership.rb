class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { viewer: 0, editor: 1, owner: 2 }

  validates :project_id, uniqueness: { scope: :user_id }
end
