class DocumentBookmarksController < BaseController
  BOOKMARK_QUERY_MAX_LENGTH = 100
  SAVED_BOOKMARKS_PER_PAGE = 20

  SavedBookmarkPage = Struct.new(:items, :total_count, :page, :total_pages, :per_page, keyword_init: true) do
    def any?
      items.any?
    end

    def summary_label
      return "#{total_count}件" if total_count <= per_page

      "#{items.size} / #{total_count}件"
    end

    def range_label
      return if total_count <= per_page || items.empty?

      first_item = ((page - 1) * per_page) + 1
      last_item = first_item + items.size - 1
      "#{first_item}-#{last_item}件目を表示"
    end

    def multiple_pages?
      total_pages > 1
    end

    def previous_page
      page - 1 if page > 1
    end

    def next_page
      page + 1 if page < total_pages
    end
  end

  def index
    @bookmark_project_code = params[:project_code].to_s.strip.presence
    @bookmark_query = bookmark_query
    @bookmark_project_options = bookmark_project_options
    @selected_bookmark_project = selected_bookmark_project
    @bookmark_project_filter_active = @bookmark_project_code.present?
    @bookmark_search_active = @bookmark_query.present?
    @saved_bookmark_filter_active = @bookmark_project_filter_active || @bookmark_search_active
    @recent_documents_query = recent_documents_query

    favorite_bookmark_relation = bookmarks_for(:favorite)
    read_later_bookmark_relation = bookmarks_for(:read_later)
    @favorite_bookmarks_page = paginate_bookmarks(favorite_bookmark_relation, :favorite_page)
    @read_later_bookmarks_page = paginate_bookmarks(read_later_bookmark_relation, :read_later_page)
    @favorite_bookmarks = @favorite_bookmarks_page.items
    @read_later_bookmarks = @read_later_bookmarks_page.items
    @favorite_bookmark_document_ids = favorite_bookmark_relation.pluck(:document_id)

    @all_recent_documents = RecentDocumentsQuery.new(user: current_user, limit: 20).call
    @recent_documents = filter_recent_documents(@all_recent_documents)
  end

  def create
    document = Document.find_by!(public_id: bookmark_params[:document_id])
    require_document_access!(document)

    current_user.document_bookmarks.find_or_create_by!(
      document:,
      bookmark_type: bookmark_type
    )

    redirect_to_back notice: bookmark_created_message
  end

  def move_to_favorite
    bookmark = current_user.document_bookmarks.read_later.find_by!(public_id: params[:public_id])
    require_document_access!(bookmark.document)

    DocumentBookmark.transaction do
      current_user.document_bookmarks.find_or_create_by!(
        document: bookmark.document,
        bookmark_type: :favorite
      )
      bookmark.destroy!
    end

    redirect_to_back fallback_location: bookmark_fallback_location, notice: "お気に入りへ移しました。"
  end

  def destroy
    bookmark = current_user.document_bookmarks.find_by!(public_id: params[:public_id])
    bookmark.destroy!

    redirect_to_back fallback_location: bookmark_fallback_location, notice: "文書ショートカットを解除しました。"
  end

  private

  def bookmarks_for(type)
    bookmarks = current_user.document_bookmarks
      .public_send(type)
      .joins(document: :project)
      .includes(document: [:project, :latest_version])
      .readable_by(current_user)

    if @bookmark_project_filter_active
      return bookmarks.none unless @selected_bookmark_project

      bookmarks = bookmarks.where(documents: { project_id: @selected_bookmark_project.id })
    end

    bookmarks = filter_bookmarks_by_query(bookmarks) if @bookmark_search_active

    bookmarks.order(created_at: :desc)
  end

  def paginate_bookmarks(bookmarks, param_name)
    total_count = bookmarks.count
    total_pages = total_count.zero? ? 1 : (total_count.to_f / SAVED_BOOKMARKS_PER_PAGE).ceil
    page = [normalized_page_param(param_name), total_pages].min
    items = bookmarks.limit(SAVED_BOOKMARKS_PER_PAGE).offset((page - 1) * SAVED_BOOKMARKS_PER_PAGE).to_a

    SavedBookmarkPage.new(
      items:,
      total_count:,
      page:,
      total_pages:,
      per_page: SAVED_BOOKMARKS_PER_PAGE
    )
  end

  def normalized_page_param(param_name)
    value = Integer(params[param_name], exception: false)
    return 1 unless value&.positive?

    value
  end

  def bookmark_fallback_location
    navigation_params = bookmark_navigation_params
    return root_path if navigation_params.blank?

    document_bookmarks_path(navigation_params)
  end

  def bookmark_navigation_params
    params.permit(:project_code, :bookmark_q, :recent_q, :favorite_page, :read_later_page).to_h.compact_blank
  end

  def filter_bookmarks_by_query(bookmarks)
    query = "%#{ActiveRecord::Base.sanitize_sql_like(@bookmark_query.downcase)}%"

    bookmarks.where(
      "LOWER(documents.title) LIKE :query OR LOWER(projects.name) LIKE :query OR LOWER(projects.code) LIKE :query",
      query:
    )
  end

  def bookmark_project_options
    project_ids = current_user.document_bookmarks
      .readable_by(current_user)
      .distinct
      .pluck("documents.project_id")

    Project.where(id: project_ids).order(:name, :code)
  end

  def selected_bookmark_project
    return unless @bookmark_project_code

    @bookmark_project_options.find { |project| project.code == @bookmark_project_code }
  end

  def filter_recent_documents(documents)
    return documents if recent_documents_query.blank?

    query = recent_documents_query.downcase
    documents.select do |document|
      [document.title, document.project.name].any? { _1.to_s.downcase.include?(query) }
    end
  end

  def bookmark_query
    @bookmark_query ||= params[:bookmark_q].to_s.strip.slice(0, BOOKMARK_QUERY_MAX_LENGTH)
  end

  def recent_documents_query
    @recent_documents_query ||= params[:recent_q].to_s.strip.slice(0, BOOKMARK_QUERY_MAX_LENGTH)
  end

  def bookmark_params
    params.require(:document_bookmark).permit(:document_id, :bookmark_type)
  end

  def bookmark_type
    value = bookmark_params[:bookmark_type].presence || "favorite"
    return value if DocumentBookmark.bookmark_types.key?(value)

    "favorite"
  end

  def bookmark_created_message
    bookmark_type == "read_later" ? "後で読むに追加しました。" : "お気に入りに追加しました。"
  end
end
