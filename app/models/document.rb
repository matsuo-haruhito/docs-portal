class Document < ApplicationRecord
  belongs_to :project
  belongs_to :latest_version, class_name: "DocumentVersion", optional: true

  has_many :document_versions, dependent: :destroy
  has_many :document_permissions, dependent: :destroy

  enum :category, {
    spec: 0,
    manual: 1,
    meeting_note: 2,
    contract: 3,
    other: 9
  }

  enum :document_kind, {
    markdown: 0,
    pdf: 1,
    excel: 2,
    word: 3,
    mixed: 4
  }

  enum :visibility_policy, {
    internal_only: 0,
    restricted_external: 1,
    public_with_login: 2
  }

  validates :title, :slug, presence: true
  validates :slug, uniqueness: { scope: :project_id }

  def external_viewable_by?(user)
    return false unless user&.external?
    return false if internal_only?

    document_permissions.where(user_id: user.id).exists? ||
      document_permissions.where(company_id: user.company_id, user_id: nil).exists?
  end
end
