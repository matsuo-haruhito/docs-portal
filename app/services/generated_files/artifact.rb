module GeneratedFiles
  Artifact = Data.define(:path, :content, :content_type) do
    def initialize(path:, content:, content_type: "text/plain")
      super(path: path.to_s, content: content.to_s, content_type: content_type.to_s)
    end
  end
end
