module SeedSupport
  class DocusaurusDiagramPage
    FENCE = "`" * 3

    def initialize(source:, relative:, language:, generated_id:)
      @source = Pathname(source)
      @relative = Pathname(relative)
      @language = language
      @generated_id = generated_id
    end

    def markdown
      [
        "---",
        "id: #{@generated_id}",
        "---",
        "",
        "# #{title}",
        "",
        "#{FENCE}#{@language}",
        body,
        FENCE,
        ""
      ].join("\n")
    end

    private

    def title
      @relative.basename.sub_ext("").to_s
    end

    def body
      File.read(@source)
    end
  end
end
