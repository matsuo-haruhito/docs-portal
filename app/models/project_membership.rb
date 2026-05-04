class ProjectMembership < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "pmem"

  belongs_to :project
  belongs_to :user

  enum :role, { viewer: 0, editor: 1, owner: 2 }

  validates :project_id, uniqueness: { scope: :user_id }

  after_commit :broadcast_document_tree_refresh_later
end
