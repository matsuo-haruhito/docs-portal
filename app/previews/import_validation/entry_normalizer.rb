module ImportValidation
  class EntryNormalizer
    def initialize(entries:, entry_class:)
      @entries = Array(entries)
      @entry_class = entry_class
    end

    def call
      entries.map { normalize_entry(_1) }
    end

    private

    attr_reader :entries, :entry_class

    def normalize_entry(value)
      return value if value.is_a?(entry_class)

      entry_class.new(
        source_path: value.fetch(:source_path),
        title: value[:title],
        frontmatter: value.fetch(:frontmatter, {}),
        content: value[:content]
      )
    end
  end
end
