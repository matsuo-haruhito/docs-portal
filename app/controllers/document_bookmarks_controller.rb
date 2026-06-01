class DocumentBookmarksController < BaseController
  def index
    @favorite_bookmarks = bookmarks_for(:favorite)
    @read_later_bookmarks = bookmarks_for(:read_later)
    @recent_documents_query = recent_documents_query
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
    current_user.document_bookmarks
      .public_send(type)
      .includes(document: [:project, :latest_version])
      .readable_by(current_user)
      .order(created_at: :desc)
  end

  def filter_recent_documents(documents)
    return documents if recent_documents_query.blank?

    query = recent_documents_query.downcase
    documents.select do |document|
      [document.title, document.project.name].any? { _1.to_s.downcase.include?(query) }
    end
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
