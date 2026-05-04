class DocumentDuplicateDetector
  Candidate = Data.define(:reason, :documents, :value) do
    def count
      documents.size
    end
  end

  def initialize(scope: Document.all)
    @scope = scope
  end

  def call
    [
      *duplicates_by_title,
      *duplicates_by_latest_source_relative_path,
      *duplicates_by_latest_source_basename
    ].sort_by { |candidate| [candidate.reason.to_s, candidate.value.to_s] }
  end

  private

  attr_reader :scope

  def documents
    @documents ||= scope.includes(:latest_version).to_a
  end

  def duplicates_by_title
    group_duplicates(:same_title) { normalize_text(_1.title) }
  end

  def duplicates_by_latest_source_relative_path
    group_duplicates(:same_source_relative_path) do |document|
      normalize_path(document.latest_version&.source_relative_path)
    end
  end

  def duplicates_by_latest_source_basename
    group_duplicates(:same_source_basename) do |document|
      normalize_text(document.latest_version&.source_basename)
    end
  end

  def group_duplicates(reason)
    documents
      .group_by { |document| yield(document) }
      .filter_map do |value, grouped_documents|
        next if value.blank?
        next if grouped_documents.size < 2

        Candidate.new(reason:, value:, documents: grouped_documents.sort_by(&:id))
      end
  end

  def normalize_text(value)
    value.to_s.unicode_normalize(:nfkc).strip.downcase.presence
  end

  def normalize_path(value)
    normalize_text(value)&.tr("\\", "/")
  end
end
