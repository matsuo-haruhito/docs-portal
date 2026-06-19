class DocumentCommentWorkspaceSearch
  COMMENT_QUERY_MAX_LENGTH = 100
  COMMENT_AUTHOR_OPTIONS_LIMIT = 50

  attr_reader :query, :author_options, :selected_author

  def initialize(user:, query:, author_public_id: nil, author_candidates: [])
    @user = user
    @query = query.to_s.strip.slice(0, COMMENT_QUERY_MAX_LENGTH)
    @normalized_query = @query.downcase
    @author_options = normalize_author_options(author_candidates)
    @author_public_id = author_public_id.to_s.strip
    @selected_author = @author_options.find { |author| author.public_id == @author_public_id }
  end

  def active?
    query_active? || author_active?
  end

  def query_active?
    query.present?
  end

  def author_active?
    selected_author.present?
  end

  def author_public_id
    selected_author&.public_id.to_s
  end

  def filter_questions(threads)
    records = threads.to_a
    return records unless active?

    records.select do |thread|
      question_matches_text?(thread) && question_matches_author?(thread)
    end
  end

  def filter_reviews(comments)
    records = comments.to_a
    return records unless active?

    records.select do |comment|
      review_matches_text?(comment) && review_matches_author?(comment)
    end
  end

  private

  def normalize_author_options(author_candidates)
    Array(author_candidates)
      .compact
      .uniq(&:id)
      .sort_by { |author| [author.display_name.to_s.downcase, author.public_id.to_s] }
      .first(COMMENT_AUTHOR_OPTIONS_LIMIT)
  end

  def question_matches_text?(thread)
    return true unless query_active?

    question_search_fields(thread).any? { |value| matches_text?(value) } ||
      visible_replies(thread).any? { |reply| question_reply_search_fields(reply).any? { |value| matches_text?(value) } }
  end

  def question_matches_author?(thread)
    return true unless author_active?

    thread.author_id == selected_author.id || visible_replies(thread).any? { |reply| reply.author_id == selected_author.id }
  end

  def review_matches_text?(comment)
    return true unless query_active?

    review_search_fields(comment).any? { |value| matches_text?(value) }
  end

  def review_matches_author?(comment)
    return true unless author_active?

    comment.author_id == selected_author.id
  end

  def visible_replies(thread)
    thread.replies.visible_to(@user)
  end

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
