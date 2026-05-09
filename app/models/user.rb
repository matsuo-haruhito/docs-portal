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
  has_many :access_requests, class_name: "AccessRequest", foreign_key: :requester_id, dependent: :destroy
  has_many :approved_access_requests, class_name: "AccessRequest", foreign_key: :approver_id, dependent: :nullify
  has_many :requested_document_approval_requests, class_name: "DocumentApprovalRequest", foreign_key: :requester_id, dependent: :destroy
  has_many :approved_document_approval_requests, class_name: "DocumentApprovalRequest", foreign_key: :approver_id, dependent: :nullify
  has_many :acted_document_approval_requests, class_name: "DocumentApprovalRequest", foreign_key: :acted_by_id, dependent: :nullify
  has_many :user_consents, dependent: :destroy
  has_many :consent_terms, through: :user_consents

  enum :user_type, { internal: 0, external: 1, company_master_admin: 2 }

  before_validation :normalize_email_address

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

  def display_name
    name.presence || email_address
  end

  def email_domain
    email_address.to_s.split("@", 2).last.presence
  end

  private

  def normalize_email_address
    self.email_address = email_address.to_s.strip.downcase.presence
  end
end
