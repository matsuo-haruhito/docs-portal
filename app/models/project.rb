class Project < ApplicationRecord
  include PublicIdentifiable
  include ProjectAccess

  public_id_prefix "prj"

  has_many :documents, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships

  validates :code, :name, presence: true
  validates :code, uniqueness: true
end
