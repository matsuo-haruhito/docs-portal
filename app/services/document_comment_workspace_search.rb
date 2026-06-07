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
      question_search_fields(thread).any? { |value| matches_text?(value) } ||
        thread.replies.visible_to(@user).any? { |reply| question_reply_search_fields(reply).any? { |value| matches_text?(value) } }
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

  def question_search_fields(thread)
    [
      thread.body,
      author_name(thread),
      document_version_label(thread)
    ]
  end

  def question_reply_search_fields(reply)
    [
      reply.body,
      author_name(reply)
    ]
  end

  def review_search_fields(comment)
    [
      comment.body,
      author_name(comment),
      document_version_label(comment),
      comment.source_path,
      comment.text_anchor_path,
      comment.text_anchor_label,
      comment.location_label
    ]
  end

  def author_name(record)
    return unless record.respond_to?(:author)

    record.author&.name
  end

  def document_version_label(record)
    return unless record.respond_to?(:document_version)

    record.document_version&.version_label
  end

  def matches_text?(value)
    value.to_s.downcase.include?(@normalized_query)
  end
end
