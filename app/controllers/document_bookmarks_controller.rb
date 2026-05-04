class DocumentBookmarksController < BaseController
  def index
    @favorite_bookmarks = bookmarks_for(:favorite)
    @read_later_bookmarks = bookmarks_for(:read_later)
    @recent_documents = RecentDocumentsQuery.new(user: current_user, limit: 20).call
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

  def bookmark_params
    params.require(:document_bookmark).permit(:document_id, :bookmark_type)
  end

  def bookmark_type
    value = bookmark_params[:bookmark_type].presence || "favorite"
    raise ApplicationError::BadRequest, "bookmark type is invalid" unless DocumentBookmark.bookmark_types.key?(value)

    value
  end

  def bookmark_created_message
    bookmark_type == "read_later" ? "後で読むに追加しました。" : "お気に入りに追加しました。"
  end
end
