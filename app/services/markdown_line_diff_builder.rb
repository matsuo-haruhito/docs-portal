class MarkdownLineDiffBuilder
  MAX_FILE_BYTES = 256.kilobytes
  CONTEXT_LINES = 3

  Line = Struct.new(:kind, :old_number, :new_number, :text, keyword_init: true)
  FileDiff = Struct.new(:status, :path, :too_large, :lines, :message, keyword_init: true)

  def initialize(current_version:, previous_version:, file_rows:)
    @current_version = current_version
    @previous_version = previous_version
    @file_rows = file_rows
  end

  def call
    return [] unless @previous_version

    @file_rows
      .select { |row| markdown_file?(row.fetch(:file, nil) || row.fetch(:previous_file, nil)) }
      .map { |row| build_file_diff(row) }
  end

  private

  def build_file_diff(row)
    current_file = row.fetch(:status) == :removed ? nil : row.fetch(:file)
    previous_file = row.fetch(:previous_file)
    path = row.fetch(:path)

    if file_too_large?(current_file) || file_too_large?(previous_file)
      return FileDiff.new(
        status: row.fetch(:status),
        path: path,
        too_large: true,
        lines: [],
        message: "ファイルサイズが大きいため、行単位diffは省略しました。"
      )
    end

    old_lines = previous_file ? read_text_lines(previous_file) : []
    new_lines = current_file ? read_text_lines(current_file) : []

    FileDiff.new(
      status: row.fetch(:status),
      path: path,
      too_large: false,
      lines: LineDiffBuilder.new(old_lines, new_lines, context_lines: CONTEXT_LINES, line_class: Line).call,
      message: nil
    )
  rescue Errno::ENOENT, ActiveRecord::RecordNotFound
    FileDiff.new(
      status: row.fetch(:status),
      path: path,
      too_large: false,
      lines: [],
      message: "元ファイルを読み込めなかったため、行単位diffを表示できません。"
    )
  end

  def markdown_file?(file)
    return false unless file

    File.extname(file.file_name.to_s).downcase.in?(%w[.md .markdown .mdx])
  end

  def file_too_large?(file)
    file.present? && file.file_size.to_i > MAX_FILE_BYTES
  end

  def read_text_lines(file)
    file.absolute_path.read(encoding: "UTF-8", invalid: :replace, undef: :replace).lines.map(&:chomp)
  end
end
