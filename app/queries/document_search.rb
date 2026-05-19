class DocumentSearch
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
      .left_joins(:document_tags, :document_keywords, document_versions: :document_files)
      .where(DocumentQuerying::SearchMatchCatalog.sql_condition, pattern:, normalized_pattern:)
  end

  def match_labels_for(document)
    return [] if blank?

    DocumentQuerying::SearchMatchCatalog.targets.filter_map do |target|
      target.label if target.value_resolver.call(document).any? { value_matches?(_1) }
    end
  end

  def self.match_target_labels
    DocumentQuerying::SearchMatchCatalog.labels
  end

  private

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
