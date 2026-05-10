class ZipImportDocumentScanner
  DocumentCandidate = Data.define(
    :absolute_path,
    :logical_path,
    :title,
    :slug,
    :frontmatter,
    :document_kind,
    :attachment_paths,
    :warnings
  )

  ScanResult = Data.define(:documents, :orphan_files, :skipped_files, :warnings)
  CANDIDATE_POLICIES = %i[all_files renderable_only].freeze

  def initialize(root:, candidate_policy: :all_files)
    @root = Pathname(root)
    @candidate_policy = candidate_policy.to_sym
    unless CANDIDATE_POLICIES.include?(@candidate_policy)
      raise ArgumentError, "unknown candidate_policy: #{candidate_policy}"
    end
    @path_classifier = ZipImport::PathClassifier.new(root:)
  end

  def call
    raw_document_files = all_files.select { document_candidate_file?(_1) }
    raw_documents = raw_document_files.map { document_candidate_builder.call(_1) }
    attachment_only_paths = raw_documents
      .select { path_classifier.renderable_document_file?(_1.absolute_path) }
      .flat_map(&:attachment_paths)
      .uniq - raw_documents.map(&:absolute_path)
    documents = raw_documents.reject { attachment_only_paths.include?(_1.absolute_path) }
    attached_paths = documents.flat_map(&:attachment_paths).uniq
    remaining_files = all_files.reject { attached_paths.include?(_1) || documents.map(&:absolute_path).include?(_1) }
    orphan_files = remaining_files.reject { path_classifier.ignored_file?(_1) }.map { path_classifier.logical_path_for(_1) }
    skipped_files = remaining_files.select { path_classifier.ignored_file?(_1) }.map { path_classifier.logical_path_for(_1) }

    ScanResult.new(
      documents:,
      orphan_files: orphan_files.sort,
      skipped_files: skipped_files.sort,
      warnings: documents.flat_map(&:warnings)
    )
  end

  def markdown_file?(path)
    path_classifier.markdown_file?(path)
  end

  def diagram_file?(path)
    path_classifier.diagram_file?(path)
  end

  def renderable_document_file?(path)
    path_classifier.renderable_document_file?(path)
  end

  def content_type_for(path)
    path_classifier.content_type_for(path)
  end

  private

  attr_reader :root, :path_classifier, :candidate_policy

  def document_candidate_file?(path)
    return false if path_classifier.ignored_file?(path)
    return path_classifier.renderable_document_file?(path) if candidate_policy == :renderable_only

    true
  end

  def all_files
    @all_files ||= Dir.glob(root.join("**", "*").to_s, File::FNM_DOTMATCH)
      .map { Pathname(_1) }
      .select(&:file?)
      .sort_by(&:to_s)
  end

  def document_candidate_builder
    @document_candidate_builder ||= ZipImport::DocumentCandidateBuilder.new(
      root:,
      path_classifier:,
      document_candidate_class: DocumentCandidate
    )
  end

  def logical_path_for(path)
    path_classifier.logical_path_for(path)
  end
end
