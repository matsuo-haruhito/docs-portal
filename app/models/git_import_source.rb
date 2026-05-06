class GitImportSource < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "gis"

  belongs_to :project
  belongs_to :created_by, class_name: "User"
  has_many :git_import_runs, dependent: :nullify

  encrypts :credential_secret

  enum :provider, {
    github: 0
  }

  enum :auth_type, {
    github_app: 0,
    fine_grained_pat: 1,
    deploy_key: 2,
    no_auth: 9
  }

  validates :repository_full_name, :branch, :source_path, :auth_type, presence: true
  validates :repository_full_name, format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be owner/repo" }
  validates :source_path, format: { with: %r{\A[^/].*\z}, message: "must be a relative path" }
  validates :repository_full_name, uniqueness: { scope: %i[project_id branch source_path] }
  validate :source_path_must_be_safe
  validate :credential_presence_for_pull_auth

  scope :enabled_only, -> { where(enabled: true) }

  def to_param
    public_id
  end

  def normalized_source_path
    Pathname.new(source_path.to_s).cleanpath.to_s.delete_prefix("./")
  end

  def mark_synced!(commit_sha)
    update!(last_synced_commit_sha: commit_sha, last_synced_at: Time.current)
  end

  private

  def source_path_must_be_safe
    value = source_path.to_s
    normalized = Pathname.new(value).cleanpath.to_s
    errors.add(:source_path, "must be a relative path") if value.blank? || value.start_with?("/") || normalized == "." || normalized == ".." || normalized.start_with?("../")
  end

  def credential_presence_for_pull_auth
    return unless fine_grained_pat?

    errors.add(:credential_secret, "is required for fine-grained PAT auth") if credential_secret.blank?
  end
end
