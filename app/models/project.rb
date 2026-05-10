class Project < ApplicationRecord
  include PublicIdentifiable
  include ProjectAccess

  public_id_prefix "prj"

  belongs_to :company, optional: true

  has_many :documents, dependent: :destroy
  has_many :document_sets, dependent: :destroy
  has_many :document_catalogs, dependent: :destroy
  has_many :document_delivery_logs, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships
  has_many :project_consent_settings, dependent: :destroy
  has_many :consent_terms, through: :project_consent_settings
  has_many :git_import_sources, dependent: :destroy
  has_many :import_route_settings, dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  after_commit :broadcast_document_tree_refresh_later

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
