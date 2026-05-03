class Project < ApplicationRecord
  include PublicIdentifiable
  include ProjectAccess

  public_id_prefix "prj"

  has_many :documents, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  def to_param
    code
  end

  def default_site_version_for(user)
    documents.includes(:latest_version)
      .map(&:latest_version)
      .compact
      .select { _1.rendered_site_available? && _1.viewable_by?(user) }
      .max_by(&:published_at)
  end
end
