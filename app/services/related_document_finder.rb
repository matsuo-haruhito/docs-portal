class RelatedDocumentFinder
  Result = Data.define(:document, :relation_type, :source)

  def initialize(document:, user:, limit: 10)
    @document = document
    @user = user
    @limit = limit
  end

  def explicit_relations
    @document.source_document_relations
      .includes(:target_document)
      .order(:relation_type, :sort_order, :id)
      .filter_map do |relation|
        target = relation.target_document
        next unless target.viewable_by?(@user)

        Result.new(document: target, relation_type: relation.relation_type, source: :explicit)
      end
  end

  def inferred_relations
    return [] unless current_version&.source_relative_path.present?

    candidates = candidate_documents
      .reject { _1.id == @document.id }
      .select { _1.viewable_by?(@user) }
      .map { |candidate| inferred_result_for(candidate) }
      .compact
      .uniq { _1.document.id }

    candidates.first(@limit)
  end

  def grouped_results
    {
      explicit: explicit_relations,
      inferred: inferred_relations
    }
  end

  private

  def current_version
    @current_version ||= @document.latest_version || @document.document_versions.order(created_at: :desc).first
  end

  def candidate_documents
    @document.project.documents
      .includes(:latest_version)
      .where.not(latest_version_id: nil)
      .order(:title)
  end

  def inferred_result_for(candidate)
    candidate_version = candidate.latest_version
    return unless candidate_version&.source_relative_path.present?

    relation_type = inferred_relation_type(candidate_version)
    return unless relation_type

    Result.new(document: candidate, relation_type: relation_type, source: :inferred)
  end

  def inferred_relation_type(candidate_version)
    return :same_source_basename if same_source_basename?(candidate_version)
    return :same_source_directory if same_source_directory?(candidate_version)

    nil
  end

  def same_source_basename?(candidate_version)
    current_version.source_basename.present? &&
      current_version.source_basename == candidate_version.source_basename &&
      current_version.source_extension != candidate_version.source_extension
  end

  def same_source_directory?(candidate_version)
    current_version.source_directory.present? &&
      current_version.source_directory == candidate_version.source_directory
  end
end
