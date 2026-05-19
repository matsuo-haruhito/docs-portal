class DocumentSearch
  MatchSummary = Data.define(:label, :value)
  MATCH_SUMMARY_LIMIT = 3
  MATCH_VALUE_MAX_LENGTH = 80

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
    match_summaries_for(document).map(&:label)
  end

  def match_summaries_for(document, limit: MATCH_SUMMARY_LIMIT)
    return [] if blank?

    DocumentQuerying::SearchMatchCatalog.targets.filter_map do |target|
      matched_value = first_matching_value(target.value_resolver.call(document))
      MatchSummary.new(label: target.label, value: truncate_match_value(matched_value)) if matched_value.present?
    end.first(limit)
  end

  def self.match_target_labels
    DocumentQuerying::SearchMatchCatalog.labels
  end

  private

  def first_matching_value(values)
    Array(values).find { value_matches?(_1) }
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

  def truncate_match_value(value)
    value.to_s.squish.truncate(MATCH_VALUE_MAX_LENGTH)
  end

  def normalize_for_match(value)
    value.to_s.unicode_normalize(:nfkc).downcase.squish
  end
end
