class DocumentSearch
  MatchTarget = Data.define(:label, :sql, :normalized_sql, :value_resolver)

  MATCH_TARGETS = [
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

  attr_reader :keyword

  def initialize(keyword)
    @keyword = keyword.to_s.strip
  end

  def blank?
    keyword.blank?
  end

  def apply(scope)
    return scope if blank?

    scope
      .left_joins(:document_keywords, document_versions: :document_files)
      .where(sql_condition, pattern:, normalized_pattern:)
  end

  def match_labels_for(document)
    return [] if blank?

    MATCH_TARGETS.filter_map do |target|
      target.label if target.value_resolver.call(document).any? { value_matches?(_1) }
    end
  end

  def self.match_target_labels
    MATCH_TARGETS.map(&:label)
  end

  private

  def sql_condition
    MATCH_TARGETS.flat_map { [_1.sql, _1.normalized_sql] }.compact.map { "(#{_1})" }.join(" OR ")
  end

  def pattern
    "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
  end

  def normalized_pattern
    "%#{ActiveRecord::Base.sanitize_sql_like(normalized_keyword)}%"
  end

  def normalized_keyword
    DocumentKeyword.normalize(keyword)
  end

  def value_matches?(value)
    return false if value.blank?

    normalize_for_match(value).include?(normalize_for_match(keyword))
  end

  def normalize_for_match(value)
    value.to_s.unicode_normalize(:nfkc).downcase.squish
  end
end
