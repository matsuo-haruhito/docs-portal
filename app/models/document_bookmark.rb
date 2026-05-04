class DocumentBookmark < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dbm"

  belongs_to :user
  belongs_to :document

  enum :bookmark_type, {
    favorite: 0,
    read_later: 1
  }

  validates :bookmark_type, presence: true
  validates :document_id, uniqueness: { scope: %i[user_id bookmark_type] }

  scope :for_user, ->(user) { where(user:) }
  scope :readable_by, ->(user) { joins(:document).merge(Document.accessible_to(user)) }

  def to_param
    public_id
  end
end
