require "nokogiri"

class RenderedHtmlDiffBuilder
  MAX_FILE_BYTES = 512.kilobytes
  CONTEXT_LINES = 2
  MAX_TABLES = 20
  MAX_TABLE_CELLS = 500

  Line = Struct.new(:kind, :old_number, :new_number, :text, keyword_init: true)
  TableCell = Struct.new(:kind, :old_text, :new_text, keyword_init: true)
  TableRow = Struct.new(:kind, :cells, keyword_init: true)
  TableDiff = Struct.new(:index, :status, :rows, :message, keyword_init: true)
  HtmlDiff = Struct.new(:available, :too_large, :lines, :table_diffs, :message, keyword_init: true)

  def initialize(current_version:, previous_version:)
    @current_version = current_version
    @previous_version = previous_version
  end

  def call
    return unavailable("比較対象の前版がありません。") unless @previous_version
    return unavailable("旧版または新版のHTML本文が未生成です。") unless html_available?(@previous_version) && html_available?(@current_version)

    old_path = @previous_version.site_entry_absolute_path
    new_path = @current_version.site_entry_absolute_path
    if too_large?(old_path) || too_large?(new_path)
      return HtmlDiff.new(available: true, too_large: true, lines: [], table_diffs: [], message: "HTML本文が大きいため、HTML差分は省略しました。")
    end

    old_html = old_path.read
    new_html = new_path.read
    old_document = sanitized_document(old_html)
    new_document = sanitized_document(new_html)
    old_lines = extract_visible_text_lines(old_document)
    new_lines = extract_visible_text_lines(new_document)

    HtmlDiff.new(
      available: true,
      too_large: false,
      lines: LineDiffBuilder.new(old_lines, new_lines, context_lines: CONTEXT_LINES, line_class: Line).call,
      table_diffs: build_table_diffs(old_document, new_document),
      message: nil
    )
  rescue Errno::ENOENT, ActiveRecord::RecordNotFound
    unavailable("HTML本文を読み込めなかったため、HTML差分を表示できません。")
  end

  private

  def unavailable(message)
    HtmlDiff.new(available: false, too_large: false, lines: [], table_diffs: [], message: message)
  end

  def html_available?(version)
    version&.rendered_site_available?
  end

  def too_large?(path)
    path.size > MAX_FILE_BYTES
  end

  def sanitized_document(html)
    document = Nokogiri::HTML5.parse(html)
    document.css("script, style, noscript, svg, nav, footer, .navbar, .theme-doc-sidebar-container, .table-of-contents, .portal-site-nav, .document-version-switcher").remove
    document
  end

  def extract_visible_text_lines(document)
    root = document.at_css("main, article, .markdown, .theme-doc-markdown, body") || document
    root.css("h1, h2, h3, h4, h5, h6, p, li, blockquote, th, td, pre, code").map do |node|
      normalize_text(node.text)
    end.reject(&:blank?)
  end

  def build_table_diffs(old_document, new_document)
    old_tables = extract_tables(old_document)
    new_tables = extract_tables(new_document)
    table_count = [old_tables.length, new_tables.length].max

    (0...[table_count, MAX_TABLES].min).filter_map do |index|
      old_table = old_tables[index]
      new_table = new_tables[index]
      table_diff(index: index + 1, old_table: old_table, new_table: new_table)
    end
  end

  def table_diff(index:, old_table:, new_table:)
    if old_table.blank?
      return TableDiff.new(index: index, status: :added, rows: table_rows_for_added_table(new_table), message: nil)
    end
    if new_table.blank?
      return TableDiff.new(index: index, status: :removed, rows: table_rows_for_removed_table(old_table), message: nil)
    end

    cell_count = [old_table, new_table].flatten.size
    if cell_count > MAX_TABLE_CELLS
      return TableDiff.new(index: index, status: :skipped, rows: [], message: "セル数が多いため、この表のセル単位diffは省略しました。")
    end

    rows = compare_table_rows(old_table, new_table)
    changed = rows.any? { |row| row.kind != :context || row.cells.any? { |cell| cell.kind != :context } }
    return unless changed

    TableDiff.new(index: index, status: :changed, rows: rows, message: nil)
  end

  def extract_tables(document)
    root = document.at_css("main, article, .markdown, .theme-doc-markdown, body") || document
    root.css("table").map do |table|
      table.css("tr").map do |row|
        row.css("th, td").map { |cell| normalize_text(cell.text) }
      end.reject(&:empty?)
    end
  end

  def compare_table_rows(old_table, new_table)
    row_count = [old_table.length, new_table.length].max
    column_count = [old_table, new_table].flatten(1).map(&:length).max.to_i

    (0...row_count).map do |row_index|
      old_row = old_table[row_index]
      new_row = new_table[row_index]
      if old_row.nil?
        TableRow.new(kind: :added, cells: table_cells_for_added_row(new_row, column_count))
      elsif new_row.nil?
        TableRow.new(kind: :removed, cells: table_cells_for_removed_row(old_row, column_count))
      else
        cells = (0...column_count).map do |column_index|
          old_text = old_row[column_index]
          new_text = new_row[column_index]
          table_cell_diff(old_text, new_text)
        end
        row_kind = cells.any? { |cell| cell.kind != :context } ? :changed : :context
        TableRow.new(kind: row_kind, cells: cells)
      end
    end
  end

  def table_cell_diff(old_text, new_text)
    return TableCell.new(kind: :context, old_text: old_text, new_text: new_text) if old_text == new_text
    return TableCell.new(kind: :added, old_text: old_text, new_text: new_text) if old_text.blank? && new_text.present?
    return TableCell.new(kind: :removed, old_text: old_text, new_text: new_text) if old_text.present? && new_text.blank?

    TableCell.new(kind: :changed, old_text: old_text, new_text: new_text)
  end

  def table_rows_for_added_table(table)
    column_count = table.map(&:length).max.to_i
    table.map { |row| TableRow.new(kind: :added, cells: table_cells_for_added_row(row, column_count)) }
  end

  def table_rows_for_removed_table(table)
    column_count = table.map(&:length).max.to_i
    table.map { |row| TableRow.new(kind: :removed, cells: table_cells_for_removed_row(row, column_count)) }
  end

  def table_cells_for_added_row(row, column_count)
    (0...column_count).map do |column_index|
      TableCell.new(kind: :added, old_text: nil, new_text: row[column_index])
    end
  end

  def table_cells_for_removed_row(row, column_count)
    (0...column_count).map do |column_index|
      TableCell.new(kind: :removed, old_text: row[column_index], new_text: nil)
    end
  end

  def normalize_text(value)
    value.to_s.gsub(/\s+/, " ").strip
  end
end
