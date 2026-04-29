module UrlHelper
  def sort_url(name)
    query_hash = request.query_parameters.symbolize_keys.except(:page)
    next_sort = params[:sort].to_s == name.to_s ? "-#{name}" : name

    url_for(params: query_hash.merge(sort: next_sort))
  end
end
