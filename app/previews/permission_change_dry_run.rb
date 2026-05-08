class PermissionChangeDryRun
  Change = Data.define(:viewer, :before_documents, :after_documents, :before_downloadable_documents, :after_downloadable_documents) do
    def gained_documents
      after_documents - before_documents
    end

    def lost_documents
      before_documents - after_documents
    end

    def unchanged_documents
      before_documents & after_documents
    end

    def gained_downloadable_documents
      after_downloadable_documents - before_downloadable_documents
    end

    def lost_downloadable_documents
      before_downloadable_documents - after_downloadable_documents
    end

    def unchanged_downloadable_documents
      before_downloadable_documents & after_downloadable_documents
    end

    def changed?
      gained_documents.any? || lost_documents.any? || gained_downloadable_documents.any? || lost_downloadable_documents.any?
    end
  end

  Result = Data.define(:project, :changes) do
    def changed_viewers
      changes.select(&:changed?)
    end

    def gained_documents
      changes.flat_map(&:gained_documents).uniq
    end

    def lost_documents
      changes.flat_map(&:lost_documents).uniq
    end

    def gained_downloadable_documents
      changes.flat_map(&:gained_downloadable_documents).uniq
    end

    def lost_downloadable_documents
      changes.flat_map(&:lost_downloadable_documents).uniq
    end
  end

  def initialize(project:, viewers:, grant: nil, revoke: nil, scope: nil)
    @project = project
    @viewers = Array(viewers)
    @grant = grant || {}
    @revoke = revoke || {}
    @scope = scope
  end

  def call
    Result.new(
      project:,
      changes: viewers.map do
        PermissionChange::ChangeBuilder.new(
          project:,
          viewer: _1,
          grant:,
          revoke:,
          scope:,
          change_class: Change
        ).call
      end
    )
  end

  private

  attr_reader :project, :viewers, :grant, :revoke, :scope
end
