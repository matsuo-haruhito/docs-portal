class ImportDryRunValidator
  Entry = Data.define(:source_path, :title, :frontmatter, :content) do
    def file_name
      File.basename(source_path.to_s)
    end
  end

  DuplicateCandidate = Data.define(:reason, :documents, :value)

  Item = Data.define(:entry, :action, :attributes, :warnings, :errors, :matched_rules, :existing_document, :duplicate_candidates) do
    def valid?
      errors.empty?
    end

    def create?
      action == :create
    end

    def update?
      action == :update
    end

    def source_path
      attributes[:source_relative_path].presence || entry.source_path
    end
  end

  Summary = Data.define(:total, :create_count, :update_count, :valid_count, :invalid_count, :warning_count, :error_count, :source_paths) do
    def valid?
      invalid_count.zero?
    end
  end

  Result = Data.define(:items) do
    def valid?
      errors.empty?
    end

    def errors
      items.flat_map(&:errors)
    end

    def warnings
      items.flat_map(&:warnings)
    end

    def creates
      items.select(&:create?)
    end

    def updates
      items.select(&:update?)
    end

    def invalid_items
      items.reject(&:valid?)
    end

    def summary
      Summary.new(
        total: items.size,
        create_count: creates.size,
        update_count: updates.size,
        valid_count: items.count(&:valid?),
        invalid_count: invalid_items.size,
        warning_count: warnings.size,
        error_count: errors.size,
        source_paths: items.map(&:source_path)
      )
    end
  end

  def initialize(project:, entries:, classifier: DocumentClassificationSuggester.new)
    @project = project
    @entries = ImportValidation::EntryNormalizer.new(entries:, entry_class: Entry).call
    @classifier = classifier
  end

  def call
    Result.new(items: entries.map do
      ImportValidation::ItemBuilder.new(
        project:,
        entry: _1,
        classifier:,
        item_class: Item,
        duplicate_candidate_class: DuplicateCandidate,
        project_documents:
      ).call
    end)
  end

  private

  attr_reader :project, :entries, :classifier

  def project_documents
    @project_documents ||= project.documents.includes(:latest_version).to_a
  end
end
