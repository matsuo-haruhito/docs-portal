module ApplicationHelper
  def page_title(*parts)
    content_for :title, parts.compact.join(" | ")
  end

  # テーブルが空でも、画面上で空状態と分かる行を補います。
  def table_tag(**options)
    options[:class] ||= %w[table]

    tag.table(**options) do
      content = capture { yield }
      empty_tbody = "<tbody></tbody>"

      if content.start_with?("<thead") && content.end_with?(empty_tbody)
        content = content.delete_suffix(empty_tbody)
        colspan = [content.scan("<th").size - 1, 1].max
        content += tag.tr { tag.td("(なし)", colspan:, class: "muted") }
      end

      content
    end
  end
end
