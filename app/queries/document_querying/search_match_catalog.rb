module DocumentQuerying
  class SearchMatchCatalog
    MatchTarget = Data.define(:label, :sql, :normalized_sql, :value_resolver)

    def self.targets
      @targets ||= [
        MatchTarget.new(
          label: "タイトル",
          sql: "documents.title ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: ->(document) { [document.title] }
        ),
        MatchTarget.new(
          label: "slug",
          sql: "documents.slug ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: ->(document) { [document.slug] }
        ),
        MatchTarget.new(
          label: "タグ",
          sql: "document_tags.name ILIKE :pattern",
          normalized_sql: "document_tags.normalized_name LIKE :normalized_pattern",
          value_resolver: lambda do |document|
            document.document_tags.flat_map { [_1.name, _1.normalized_name] }
          end
        ),
        MatchTarget.new(
          label: "バージョン",
          sql: "document_versions.version_label ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: ->(document) { document.document_versions.map(&:version_label) }
        ),
        MatchTarget.new(
          label: "source path",
          sql: [
            "document_versions.source_relative_path ILIKE :pattern",
            "document_versions.source_directory ILIKE :pattern",
            "document_versions.source_file_name ILIKE :pattern"
          ].join(" OR "),
          normalized_sql: nil,
          value_resolver: lambda do |document|
            document.document_versions.flat_map do |version|
              [version.source_relative_path, version.source_directory, version.source_file_name]
            end
          end
        ),
        MatchTarget.new(
          label: "更新サマリ",
          sql: "document_versions.changelog_summary ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: ->(document) { document.document_versions.map(&:changelog_summary) }
        ),
        MatchTarget.new(
          label: "本文",
          sql: "document_versions.search_body_text ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: ->(document) { document.document_versions.map(&:search_body_text) }
        ),
        MatchTarget.new(
          label: "添付ファイル名",
          sql: "document_files.file_name ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: lambda do |document|
            document.document_versions.flat_map { _1.document_files.map(&:file_name) }
          end
        ),
        MatchTarget.new(
          label: "添付tree path",
          sql: nil,
          normalized_sql: nil,
          value_resolver: lambda do |document|
            document.document_versions.flat_map { _1.document_files.map(&:tree_path) }
          end
        ),
        MatchTarget.new(
          label: "添付テキスト",
          sql: "document_files.search_text ILIKE :pattern",
          normalized_sql: nil,
          value_resolver: lambda do |document|
            document.document_versions.flat_map { _1.document_files.map(&:search_text) }
          end
        ),
        MatchTarget.new(
          label: "キーワード",
          sql: "document_keywords.keyword ILIKE :pattern",
          normalized_sql: "document_keywords.normalized_keyword LIKE :normalized_pattern",
          value_resolver: lambda do |document|
            document.document_keywords.flat_map { [_1.keyword, _1.normalized_keyword] }
          end
        )
      ].freeze
    end

    def self.labels
      targets.map(&:label)
    end

    def self.sql_condition
      targets.flat_map { [_1.sql, _1.normalized_sql] }.compact.map { "(#{_1})" }.join(" OR ")
    end
  end
end
