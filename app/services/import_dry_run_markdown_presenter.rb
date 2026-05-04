class ImportDryRunMarkdownPresenter
  def initialize(result)
    @result = result
  end

  def call
    [
      "# Import dry-run preview",
      "",
      summary_section,
      "",
      items_section
    ].join("\n").strip + "\n"
  end

  private

  attr_reader :result

  def summary_section
    lines = [
      "## Summary",
      "",
      "- total: #{result.items.size}",
      "- creates: #{result.creates.size}",
      "- updates: #{result.updates.size}",
      "- warnings: #{result.warnings.size}",
      "- errors: #{result.errors.size}"
    ]

    lines.join("\n")
  end

  def items_section
    return "## Items\n\nNo import candidates." if result.items.empty?

    [
      "## Items",
      "",
      *result.items.map { item_lines(_1) }.flatten
    ].join("\n")
  end

  def item_lines(item)
    attributes = item.attributes
    lines = [
      "### #{attributes[:title] || item.entry.title || item.entry.file_name}",
      "",
      "- action: #{item.action}",
      "- source_path: #{attributes[:source_relative_path] || item.entry.source_path}",
      "- category: #{attributes[:category] || '-'}",
      "- document_kind: #{attributes[:document_kind] || '-'}",
      "- visibility_policy: #{attributes[:visibility_policy] || '-'}"
    ]

    lines << "- matched_rules: #{item.matched_rules.join(', ')}" if item.matched_rules.any?
    lines.concat(message_lines("warnings", item.warnings)) if item.warnings.any?
    lines.concat(message_lines("errors", item.errors)) if item.errors.any?
    lines << ""
    lines
  end

  def message_lines(label, messages)
    ["- #{label}:", *messages.map { "  - #{_1}" }]
  end
end
