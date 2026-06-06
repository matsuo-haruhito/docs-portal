class DocumentCommentWorkspaceSearch
  COMMENT_QUERY_MAX_LENGTH = 100

  attr_reader :query

  def initialize(user:, query:)
    @user = user
    @query = query.to_s.strip.slice(0, COMMENT_QUERY_MAX_LENGTH)
    @normalized_query = @query.downcase
  end

  def active?
    query.present?
  end

  def filter_questions(threads)
    records = threads.to_a
    return records unless active?

    records.select do |thread|
      matches_text?(thread.body) || thread.replies.visible_to(@user).any? { |reply| matches_text?(reply.body) }
    end
  end

  def filter_reviews(comments)
    records = comments.to_a
    return records unless active?

    records.select do |comment|
      review_search_fields(comment).any? { |value| matches_text?(value) }
    end
  end

  private

  def review_search_fields(comment)
    [
      comment.body,
      comment.source_path,
      comment.text_anchor_path,
      comment.text_anchor_label,
      comment.location_label
    ]
  end

  def matches_text?(value)
    value.to_s.downcase.include?(@normalized_query)
  end
end
