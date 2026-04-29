class User < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "usr"

  has_secure_password

  belongs_to :company, optional: true

  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships

  enum :user_type, { internal: 0, external: 1 }

  validates :name, presence: true
  validates :email_address, presence: true
  validates :email_address, uniqueness: true
  validates :company, presence: true, if: :external?
  validates :password, presence: true, on: :create

  scope :active_only, -> { where(active: true) }

  def admin?
    internal?
  end

  def can_manage_company_master?
    internal?
  end

  def can_view_all_documents?
    internal?
  end
end
