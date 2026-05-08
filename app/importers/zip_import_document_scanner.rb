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

  def initialize(root:)
    @root = Pathname(root)
    @path_classifier = ZipImport::PathClassifier.new(root:)
  end

  def call
    document_files = all_files.select { path_classifier.document_candidate_file?(_1) }
    documents = document_files.map { document_candidate_builder.call(_1) }
    attached_paths = documents.flat_map(&:attachment_paths).uniq
    remaining_files = all_files.reject { attached_paths.include?(_1) || document_files.include?(_1) }
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

  def content_type_for(path)
    path_classifier.content_type_for(path)
  end

  private

  attr_reader :root, :path_classifier

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
