require "nokogiri"
require "set"

class RenderedHtmlDiffBuilder
  MAX_FILE_BYTES = 512.kilobytes
  CONTEXT_LINES = 2

  Line = Struct.new(:kind, :old_number, :new_number, :text, keyword_init: true)
  HtmlDiff = Struct.new(:available, :too_large, :lines, :message, keyword_init: true)

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
      return HtmlDiff.new(available: true, too_large: true, lines: [], message: "HTML本文が大きいため、HTML差分は省略しました。")
    end

    old_lines = extract_visible_text_lines(old_path.read)
    new_lines = extract_visible_text_lines(new_path.read)

    HtmlDiff.new(
      available: true,
      too_large: false,
      lines: compact_context(diff_lines(old_lines, new_lines)),
      message: nil
    )
  rescue Errno::ENOENT, ActiveRecord::RecordNotFound
    unavailable("HTML本文を読み込めなかったため、HTML差分を表示できません。")
  end

  private

  def unavailable(message)
    HtmlDiff.new(available: false, too_large: false, lines: [], message: message)
  end

  def html_available?(version)
    version&.rendered_site_available?
  end

  def too_large?(path)
    path.size > MAX_FILE_BYTES
  end

  def extract_visible_text_lines(html)
    document = Nokogiri::HTML5.parse(html)
    document.css("script, style, noscript, svg, nav, footer, .navbar, .theme-doc-sidebar-container, .table-of-contents, .portal-site-nav, .document-version-switcher").remove

    root = document.at_css("main, article, .markdown, .theme-doc-markdown, body") || document
    root.css("h1, h2, h3, h4, h5, h6, p, li, blockquote, th, td, pre, code").map do |node|
      normalize_text(node.text)
    end.reject(&:blank?)
  end

  def normalize_text(value)
    value.to_s.gsub(/\s+/, " ").strip
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
