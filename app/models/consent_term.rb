class ConsentTerm < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ctm"

  has_many :user_consents, dependent: :destroy
  has_many :users, through: :user_consents
  has_many :project_consent_settings, dependent: :destroy
  has_many :projects, through: :project_consent_settings

  enum :consent_scope, {
    global: 0,
    project: 1,
    document: 2,
    download: 3,
    shared_link: 4
  }

  enum :requirement_timing, {
    first_view: 0,
    every_version_change: 1,
    every_download: 2
  }

  validates :title, :body, :version_label, presence: true
  validates :version_label, uniqueness: { scope: :title }

  scope :active_only, -> { where(active: true) }

  def to_param
    public_id
  end
end
