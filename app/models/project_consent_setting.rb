class ProjectConsentSetting < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "pcs"

  belongs_to :project
  belongs_to :consent_term

  enum :required_on, {
    first_access: 0,
    download: 1,
    shared_link_access: 2,
    shared_link_download: 3
  }

  validates :required_on, presence: true
  validates :consent_term_id, uniqueness: { scope: %i[project_id required_on] }

  scope :enabled_only, -> { where(enabled: true) }

  def to_param
    public_id
  end
end
