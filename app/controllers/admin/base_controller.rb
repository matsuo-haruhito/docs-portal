class Admin::BaseController < BaseController
  DEFAULT_ADMIN_LIST_PER_PAGE = 25
  MAX_ADMIN_LIST_PER_PAGE = 100
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  before_action :require_admin_area_access!

  private

  def require_admin_area_access!
    raise ApplicationError::Forbidden unless admin_user? || company_master_admin?
  end

  def require_admin_only!
    raise ApplicationError::Forbidden unless admin_user?
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def admin_master_maintenance_message
    "メンテナンス中のため会社・ユーザー・案件所属の変更操作は停止しています。一覧、検索、現在の所属確認は継続できます。"
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return fallback if return_to.blank?
    return fallback unless return_to.start_with?("/")
    return fallback if return_to.start_with?("//")
    return fallback if return_to.match?(/[[:cntrl:]]/)

    return_to
  end

  def paginate_admin_list(scope, total_count)
    pagination = admin_list_pagination(total_count)

    [scope.limit(pagination[:per_page]).offset(pagination[:offset]), pagination]
  end

  def admin_list_pagination(total_count)
    per_page = bounded_admin_list_per_page
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    page = bounded_admin_list_page(total_pages)
    offset = (page - 1) * per_page

    {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      offset: offset,
      from: total_count.zero? ? 0 : offset + 1,
      to: [offset + per_page, total_count].min,
      prev_page: page > 1 ? page - 1 : nil,
      next_page: page < total_pages ? page + 1 : nil
    }
  end

  def bounded_admin_list_page(total_pages)
    page = params[:page].to_i
    page = 1 if page < 1
    [page, total_pages].min
  end

  def bounded_admin_list_per_page
    per_page = params[:per_page].to_i
    per_page = DEFAULT_ADMIN_LIST_PER_PAGE if per_page < 1
    [per_page, MAX_ADMIN_LIST_PER_PAGE].min
  end
end
