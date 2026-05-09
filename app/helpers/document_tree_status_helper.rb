module DocumentTreeStatusHelper
  def tree_item_status_icons(item)
    return [] unless item.is_a?(Document)

    icons = []
    unless tree_item_html_available?(item)
      icons << {
        text: "⚠️",
        class: "tree-item-status-icon--warning",
        title: "プレビュー画面はまだ生成されていません"
      }
    end

    if tree_item_unread?(item)
      icons << {
        id: document_tree_unread_icon_id(item),
        text: "🆕",
        class: "tree-item-status-icon--unread",
        title: "未読の文書です"
      }
    end

    icons
  end

  def document_tree_unread_icon_id(document)
    "document_tree_unread_#{document.id}"
  end

  private

  def tree_item_unread?(document)
    return false unless current_user

    tree_read_document_ids.exclude?(document.id)
  end

  def tree_read_document_ids
    @tree_read_document_ids ||= ReadConfirmation.for_user(current_user).pluck(:document_id)
  end
end
