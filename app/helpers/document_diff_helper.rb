require "set"

module DocumentDiffHelper
  SideBySideDiffRow = Data.define(:old_line, :new_line, :kind)

  def diff_line_code_with_inline_highlight(lines, index)
    line = lines[index]
    pair = diff_line_pair(lines, index)
    text_html = pair ? highlight_changed_fragment(line.text.to_s, pair.text.to_s) : ERB::Util.html_escape(line.text.to_s)

    safe_join([ERB::Util.html_escape(diff_line_prefix(line.kind)), text_html.respond_to?(:html_safe) ? text_html.html_safe : text_html])
  end

  def side_by_side_diff_rows(lines)
    rows = []
    index = 0
    line_list = Array(lines)

    while index < line_list.length
      line = line_list[index]
      next_line = line_list[index + 1]

      if line.kind == :removed && next_line&.kind == :added
        rows << SideBySideDiffRow.new(old_line: line, new_line: next_line, kind: :changed)
        index += 2
      elsif line.kind == :removed
        rows << SideBySideDiffRow.new(old_line: line, new_line: nil, kind: :removed)
        index += 1
      elsif line.kind == :added
        rows << SideBySideDiffRow.new(old_line: nil, new_line: line, kind: :added)
        index += 1
      else
        rows << SideBySideDiffRow.new(old_line: line, new_line: line, kind: line.kind)
        index += 1
      end
    end

    rows
  end

  private

  def diff_line_prefix(kind)
    return "+ " if kind == :added
    return "- " if kind == :removed

    "  "
  end

  def diff_line_pair(lines, index)
    line = lines[index]
    previous_line = index.positive? ? lines[index - 1] : nil
    next_line = lines[index + 1]

    return previous_line if line.kind == :added && previous_line&.kind == :removed
    return next_line if line.kind == :removed && next_line&.kind == :added

    nil
  end

  def highlight_changed_fragment(text, other_text)
    tokens = tokenize_diff_text(text)
    other_tokens = tokenize_diff_text(other_text)
    changed_indexes = changed_token_indexes(tokens, other_tokens)

    return ERB::Util.html_escape(text) if changed_indexes.empty?

    safe_join(tokens.each_with_index.map do |token, index|
      escaped_token = ERB::Util.html_escape(token)
      changed_indexes.include?(index) ? content_tag(:mark, escaped_token, class: "diff-inline-change") : escaped_token
    end)
  end

  def tokenize_diff_text(text)
    tokens = []
    current = +""
    current_kind = nil

    text.each_char do |char|
      kind = diff_char_kind(char)
      if current_kind == kind
        current << char
      else
        tokens << current unless current.empty?
        current = +char
        current_kind = kind
      end
    end

    tokens << current unless current.empty?
    tokens
  end

  def diff_char_kind(char)
    return :space if char.match?(/[[:space:]]/)
    return :word if char.match?(/[[:alnum:]_]/)

    :symbol
  end

  def changed_token_indexes(tokens, other_tokens)
    return Set.new(tokens.each_index) if tokens.size > 200 || other_tokens.size > 200

    unchanged_indexes = lcs_token_indexes(tokens, other_tokens)
    Set.new(tokens.each_index) - unchanged_indexes
  end

  def lcs_token_indexes(tokens, other_tokens)
    lengths = Array.new(tokens.length + 1) { Array.new(other_tokens.length + 1, 0) }

    tokens.each_with_index do |token, left_index|
      other_tokens.each_with_index do |other_token, right_index|
        lengths[left_index + 1][right_index + 1] = if token == other_token
          lengths[left_index][right_index] + 1
        else
          [lengths[left_index][right_index + 1], lengths[left_index + 1][right_index]].max
        end
      end
    end

    indexes = Set.new
    left_index = tokens.length
    right_index = other_tokens.length

    while left_index.positive? && right_index.positive?
      if tokens[left_index - 1] == other_tokens[right_index - 1]
        indexes.add(left_index - 1)
        left_index -= 1
        right_index -= 1
      elsif lengths[left_index - 1][right_index] >= lengths[left_index][right_index - 1]
        left_index -= 1
      else
        right_index -= 1
      end
    end

    indexes
  end
end