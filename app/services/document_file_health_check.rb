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
    files = scope.includes(document_version: { document: :project }).order(:id)
    missing = []
    total = 0

    files.find_each do |file|
      total += 1
      missing << file if missing.length < limit && missing_file?(file)
    end

    missing_count = files.count { missing_file?(_1) }
    Result.new(total_count: total, missing_files: missing, missing_count:)
  end

  private

  attr_reader :scope

  def missing_file?(file)
    !File.file?(file.absolute_path)
  end
end
