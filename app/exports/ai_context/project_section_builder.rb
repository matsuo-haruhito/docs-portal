module AiContext
  class ProjectSectionBuilder
    def initialize(project:, user:, mode:)
      @project = project
      @user = user
      @mode = mode
    end

    def call
      [
        "# Project: #{project.name}",
        [
          "- code: #{project.code}",
          "- exported_for: #{user.email_address}",
          "- mode: #{mode}",
          project_description
        ].compact.join("\n")
      ].join("\n\n")
    end

    private

    attr_reader :project, :user, :mode

    def project_description
      return if project.description.blank?

      "- description: #{project.description.to_s.unicode_normalize(:nfkc).squish}"
    end
  end
end
