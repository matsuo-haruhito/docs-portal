module LinkToHelper
  def edit_link_to(name, url = nil, **options)
    options = options.reverse_merge(class: "button secondary")

    if block_given?
      link_to(name, **options) { yield }
    else
      link_to(name, url, **options)
    end
  end

  def sort_link_to(name, label = nil, **options)
    label ||= name.to_s.humanize
    current_sort = params[:sort].to_s

    indicator =
      if current_sort == name.to_s
        " \u25b2"
      elsif current_sort == "-#{name}"
        " \u25bc"
      else
        ""
      end

    link_to("#{label}#{indicator}".html_safe, sort_url(name), options)
  end

  def link_to_document_file(file, **options)
    return if file.blank?

    label = "#{file.file_name} (#{number_to_human_size(file.file_size)})"
    link_to(label, file, options)
  end

  def delete_link_to(name, url, **options)
    options = options.reverse_merge(
      class: "button danger",
      form: { data: { turbo_confirm: "削除しますか？" } }
    )

    button_to(name, url, options.merge(method: :delete))
  end
end
