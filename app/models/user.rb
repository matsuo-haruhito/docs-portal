class User < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "usr"

  has_secure_password

  belongs_to :company, optional: true

  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships
  has_many :document_bookmarks, dependent: :destroy
  has_many :bookmarked_documents, through: :document_bookmarks, source: :document
  has_many :read_confirmations, dependent: :destroy
  has_many :confirmed_read_documents, through: :read_confirmations, source: :document
  has_many :user_consents, dependent: :destroy
  has_many :consent_terms, through: :user_consents

  enum :user_type, { internal: 0, external: 1, company_master_admin: 2 }

  validates :name, presence: true
  validates :email_address, presence: true
  validates :email_address, uniqueness: true
  validates :company, presence: true, if: -> { external? || company_master_admin? }
  validates :password, presence: true, on: :create

  scope :active_only, -> { where(active: true) }

  def admin?
    internal?
  end

  def can_manage_company_master?
    admin? || company_master_admin?
  end

  def can_view_all_documents?
    internal?
  end
end
