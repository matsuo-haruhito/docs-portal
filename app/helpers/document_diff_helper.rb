module DocumentDiffHelper
  def diff_line_code_with_inline_highlight(lines, index)
    line = lines[index]
    pair = diff_line_pair(lines, index)
    text_html = pair ? highlight_changed_fragment(line.text.to_s, pair.text.to_s) : ERB::Util.html_escape(line.text.to_s)

    safe_join([ERB::Util.html_escape(diff_line_prefix(line.kind)), text_html.respond_to?(:html_safe) ? text_html.html_safe : text_html])
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
    prefix_size = shared_prefix_size(text, other_text)
    left_tail = text[prefix_size..].to_s
    right_tail = other_text[prefix_size..].to_s
    suffix_size = shared_suffix_size(left_tail, right_tail)

    changed_end = suffix_size.positive? ? text.length - suffix_size : text.length
    before = text[0, prefix_size].to_s
    changed = text[prefix_size...changed_end].to_s
    after = suffix_size.positive? ? text[-suffix_size, suffix_size].to_s : ""

    safe_join([
      ERB::Util.html_escape(before),
      content_tag(:mark, ERB::Util.html_escape(changed), class: "diff-inline-change"),
      ERB::Util.html_escape(after)
    ])
  end

  def shared_prefix_size(left, right)
    max = [left.length, right.length].min
    size = 0
    size += 1 while size < max && left[size] == right[size]
    size
  end

  def shared_suffix_size(left, right)
    max = [left.length, right.length].min
    size = 0
    size += 1 while size < max && left[-size - 1] == right[-size - 1]
    size
  end
end
