class ReadConfirmation < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "rcf"

  belongs_to :user
  belongs_to :document
  belongs_to :document_version, optional: true

  validates :confirmed_at, presence: true
  validates :document_id, uniqueness: { scope: :user_id }

  before_validation :set_confirmed_at, on: :create

  scope :for_user, ->(user) { where(user:) }

  def to_param
    public_id
  end

  private

  def set_confirmed_at
    self.confirmed_at ||= Time.current
  end
end
