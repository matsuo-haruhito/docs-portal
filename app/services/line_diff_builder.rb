require "diff/lcs"
require "set"

class LineDiffBuilder
  DEFAULT_CONTEXT_LINES = 3

  Line = Struct.new(:kind, :old_number, :new_number, :text, keyword_init: true)

  def initialize(old_lines, new_lines, context_lines: DEFAULT_CONTEXT_LINES, line_class: Line)
    @old_lines = old_lines
    @new_lines = new_lines
    @context_lines = context_lines
    @line_class = line_class
  end

  def call
    compact_context(diff_lines)
  end

  private

  attr_reader :old_lines, :new_lines, :context_lines, :line_class

  def diff_lines
    old_number = 1
    new_number = 1

    Diff::LCS.sdiff(old_lines, new_lines).flat_map do |change|
      case change.action
      when "="
        line = build_line(:context, old_number, new_number, change.old_element)
        old_number += 1
        new_number += 1
        [line]
      when "+"
        line = build_line(:added, nil, new_number, change.new_element)
        new_number += 1
        [line]
      when "-"
        line = build_line(:removed, old_number, nil, change.old_element)
        old_number += 1
        [line]
      when "!"
        removed = build_line(:removed, old_number, nil, change.old_element)
        added = build_line(:added, nil, new_number, change.new_element)
        old_number += 1
        new_number += 1
        [removed, added]
      else
        []
      end
    end
  end

  def build_line(kind, old_number, new_number, text)
    line_class.new(kind: kind, old_number: old_number, new_number: new_number, text: text)
  end

  def compact_context(lines)
    changed_indexes = lines.each_index.select { |index| lines[index].kind != :context }
    return [] if changed_indexes.empty?

    keep_indexes = Set.new
    changed_indexes.each do |index|
      ([index - context_lines, 0].max..[index + context_lines, lines.length - 1].min).each do |keep_index|
        keep_indexes << keep_index
      end
    end

    compacted = []
    previous_index = nil
    keep_indexes.to_a.sort.each do |index|
      if previous_index && index > previous_index + 1
        compacted << build_line(:gap, nil, nil, "...")
      end
      compacted << lines[index]
      previous_index = index
    end

    compacted
  end
end
