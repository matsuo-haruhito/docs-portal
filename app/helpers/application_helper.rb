module ApplicationHelper
  def page_title(*parts)
    content_for :title, parts.compact.join(" | ")
  end

  def localized_label(scope, value)
    value = value.to_s
    I18n.t("labels.#{scope}.#{value}", default: value)
  end

  def document_category_label(document)
    localized_label("documents.category", document.category)
  end

  def document_kind_label(document)
    localized_label("documents.document_kind", document.document_kind)
  end

  def document_visibility_policy_label(document)
    localized_label("documents.visibility_policy", document.visibility_policy)
  end

  def document_importance_level_label(document)
    localized_label("documents.importance_level", document.importance_level)
  end

  def document_version_status_label(version)
    localized_label("document_versions.status", version.status)
  end

  def document_version_label(version)
    localized_label("document_versions.version_label", version.version_label)
  end

  def document_review_comment_type_label(comment_or_value)
    value = comment_or_value.respond_to?(:comment_type) ? comment_or_value.comment_type : comment_or_value
    localized_label("document_review_comments.comment_type", value)
  end

  def document_review_comment_status_label(comment)
    localized_label("document_review_comments.status", comment.status)
  end

  def document_approval_request_status_label(request)
    localized_label("document_approval_requests.status", request.status)
  end

  def document_relation_type_label(result)
    localized_label("document_relations.relation_type", result.relation_type)
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
