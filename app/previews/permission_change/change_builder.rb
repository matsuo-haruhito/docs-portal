module PermissionChange
  class ChangeBuilder
    def initialize(project:, viewer:, grant:, revoke:, scope:, change_class:)
      @project = project
      @viewer = viewer
      @grant = grant || {}
      @revoke = revoke || {}
      @scope = scope
      @change_class = change_class
    end

    def call
      before_documents = simulator.visible_documents
      after_documents = simulator.simulated_visible_documents
      before_downloadable_documents = simulator.downloadable_documents
      after_downloadable_documents = simulator.simulated_downloadable_documents(
        before_downloadable_documents:,
        after_documents:
      )

      change_class.new(
        viewer:,
        before_documents:,
        after_documents:,
        before_downloadable_documents:,
        after_downloadable_documents:
      )
    end

    private

    attr_reader :project, :viewer, :grant, :revoke, :scope, :change_class

    def simulator
      @simulator ||= VisibilitySimulator.new(
        project:,
        viewer:,
        grant:,
        revoke:,
        scope:
      )
    end
  end
end
