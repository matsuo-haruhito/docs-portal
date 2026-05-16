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
      .select { |row| markdown_file?(row.fetch(:file)) }
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
      lines: compact_context(diff_lines(old_lines, new_lines)),
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
    File.extname(file.file_name.to_s).downcase.in?(%w[.md .markdown])
  end

  def file_too_large?(file)
    file.present? && file.file_size.to_i > MAX_FILE_BYTES
  end

  def read_text_lines(file)
    file.absolute_path.read(encoding: "UTF-8", invalid: :replace, undef: :replace).lines.map(&:chomp)
  end

  def diff_lines(old_lines, new_lines)
    lcs = lcs_matrix(old_lines, new_lines)
    lines = []
    old_index = 0
    new_index = 0
    old_number = 1
    new_number = 1

    while old_index < old_lines.length || new_index < new_lines.length
      if old_index < old_lines.length && new_index < new_lines.length && old_lines[old_index] == new_lines[new_index]
        lines << Line.new(kind: :context, old_number: old_number, new_number: new_number, text: old_lines[old_index])
        old_index += 1
        new_index += 1
        old_number += 1
        new_number += 1
      elsif new_index < new_lines.length && (old_index == old_lines.length || lcs[old_index][new_index + 1] >= lcs[old_index + 1][new_index])
        lines << Line.new(kind: :added, old_number: nil, new_number: new_number, text: new_lines[new_index])
        new_index += 1
        new_number += 1
      else
        lines << Line.new(kind: :removed, old_number: old_number, new_number: nil, text: old_lines[old_index])
        old_index += 1
        old_number += 1
      end
    end

    lines
  end

  def lcs_matrix(old_lines, new_lines)
    matrix = Array.new(old_lines.length + 1) { Array.new(new_lines.length + 1, 0) }

    old_lines.length.downto(1) do |old_pos|
      new_lines.length.downto(1) do |new_pos|
        old_index = old_pos - 1
        new_index = new_pos - 1
        matrix[old_index][new_index] = if old_lines[old_index] == new_lines[new_index]
          matrix[old_index + 1][new_index + 1] + 1
        else
          [matrix[old_index + 1][new_index], matrix[old_index][new_index + 1]].max
        end
      end
    end

    matrix
  end

  def compact_context(lines)
    changed_indexes = lines.each_index.select { |index| lines[index].kind != :context }
    return [] if changed_indexes.empty?

    keep_indexes = Set.new
    changed_indexes.each do |index|
      ([index - CONTEXT_LINES, 0].max..[index + CONTEXT_LINES, lines.length - 1].min).each do |keep_index|
        keep_indexes << keep_index
      end
    end

    compacted = []
    previous_index = nil
    keep_indexes.to_a.sort.each do |index|
      if previous_index && index > previous_index + 1
        compacted << Line.new(kind: :gap, old_number: nil, new_number: nil, text: "...")
      end
      compacted << lines[index]
      previous_index = index
    end

    compacted
  end
end
