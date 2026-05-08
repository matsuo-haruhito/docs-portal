class DocumentFileHealthCheck
  Result = Data.define(:total_count, :missing_files, :missing_count) do
    def healthy?
      missing_count.zero?
    end
  end

  def initialize(scope = DocumentFile.all)
    @scope = scope
  end

  def call(limit: 20)
    missing = []
    total = 0
    missing_count = 0

    files.find_each do |file|
      total += 1
      next unless missing_file?(file)

      missing_count += 1
      missing << file if missing.length < limit
    end

    Result.new(total_count: total, missing_files: missing, missing_count:)
  end

  private

  attr_reader :scope

  def files
    scope.includes(document_version: { document: :project }).order(:id)
  end

  def missing_file?(file)
    !File.file?(file.absolute_path)
  end
end
