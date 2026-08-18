module LinkToHelper
  def edit_link_to(name, url = nil, **options)
    options = options.reverse_merge(class: "button secondary")
    icon = tag.i(class: "bi bi-pencil me-1", aria: { hidden: true })
    label = (icon + name).html_safe

    if block_given?
      link_to(label, name, **options) { yield }
    else
      link_to(label, url, **options)
    end
  end

  def detail_link_to(name, url, **options)
    options = options.reverse_merge(class: "button secondary")
    icon = tag.i(class: "bi bi-eye me-1", aria: { hidden: true })
    label = (icon + name).html_safe
    link_to(label, url, **options)
  end

  def back_link_to(name, url, **options)
    options = options.reverse_merge(class: "button secondary")
    icon = tag.i(class: "bi bi-arrow-left me-1", aria: { hidden: true })
    label = (icon + name).html_safe
    link_to(label, url, **options)
  end

  def link_to_document_file(file, **options)
    return if file.blank?

    label = "#{file.file_name} (#{number_to_human_size(file.file_size)})"
    link_to(label, file, options)
  end

  def delete_link_to(name, url, **options)
    confirm_message = options.delete(:confirm) || "削除しますか？この操作は元に戻せません。"
    form_options = options.delete(:form) || {}
    form_data = (form_options[:data] || {}).merge(turbo_confirm: confirm_message)

    options = options.reverse_merge(
      class: "button danger"
    )

    icon = tag.i(class: "bi bi-trash me-1", aria: { hidden: true })
    label = (icon + name).html_safe

    button_to(label, url, options.merge(method: :delete, form: form_options.merge(data: form_data)))
  end
end
