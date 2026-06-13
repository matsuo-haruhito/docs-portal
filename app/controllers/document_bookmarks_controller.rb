class DocumentBookmarksController < BaseController
  BOOKMARK_QUERY_MAX_LENGTH = 100

  def index
    @bookmark_project_code = params[:project_code].to_s.strip.presence
    @bookmark_query = bookmark_query
    @bookmark_project_options = bookmark_project_options
    @selected_bookmark_project = selected_bookmark_project
    @bookmark_project_filter_active = @bookmark_project_code.present?
    @bookmark_search_active = @bookmark_query.present?
    @saved_bookmark_filter_active = @bookmark_project_filter_active || @bookmark_search_active
    @recent_documents_query = recent_documents_query
    @favorite_bookmarks = bookmarks_for(:favorite)
    @read_later_bookmarks = bookmarks_for(:read_later)
    @favorite_bookmark_document_ids = @favorite_bookmarks.map(&:document_id)
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

    redirect_to_back notice: "お気に入りへ移しました。"
  end

  def destroy
    bookmark = current_user.document_bookmarks.find_by!(public_id: params[:public_id])
    bookmark.destroy!

    redirect_to_back notice: "文書ショートカットを解除しました。"
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
    @recent_documents_query ||= params[:recent_q].to_s.strip
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