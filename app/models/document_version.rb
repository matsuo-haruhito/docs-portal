class DocumentVersion < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ver"

  belongs_to :document
  belongs_to :published_by_user, class_name: "User", optional: true

  has_many :document_files, dependent: :destroy

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :version_label, :source_commit_hash, presence: true

  def site_root_absolute_path
    Rails.root.join("storage", "docs_sites", id.to_s)
  end

  def site_entry_relative_path
    return if site_build_path.blank?

    Pathname.new(site_build_path).join("index.html").to_s
  end

  def site_entry_absolute_path
    return if site_entry_relative_path.blank?

    path = site_root_absolute_path.join(site_entry_relative_path)
    return path if path.exist?

    legacy_html_absolute_path
  end

  def html_absolute_path
    site_entry_absolute_path
  end

  def rendered_site_available?
    site_build_path.present? && site_entry_absolute_path&.exist?
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?

    published? && document.viewable_by?(user)
  end

  def legacy_html_absolute_path
    Rails.root.join("storage", "docs_sites", site_build_path.to_s, "index.html")
  end
end
