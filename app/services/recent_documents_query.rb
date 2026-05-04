class RecentDocumentsQuery
  DEFAULT_LIMIT = 10

  def initialize(user:, limit: DEFAULT_LIMIT, scope: AccessLog.all)
    @user = user
    @limit = limit.to_i
    @scope = scope
  end

  def call
    return [] unless user&.active?

    latest_log_by_document_id
      .values
      .sort_by { [_1.accessed_at || Time.zone.at(0), _1.id] }
      .reverse
      .filter_map(&:document)
      .select { _1.viewable_by?(user) }
      .first(normalized_limit)
  end

  private

  attr_reader :user, :limit, :scope

  def latest_log_by_document_id
    scoped_logs.each_with_object({}) do |log, latest_by_document|
      document_id = log.document_id
      current = latest_by_document[document_id]

      if current.nil? || newer?(log, current)
        latest_by_document[document_id] = log
      end
    end
  end

  def scoped_logs
    scope
      .includes(:document)
      .where(user_id: user.id, action_type: AccessLog.action_types[:view])
      .where.not(document_id: nil)
  end

  def newer?(candidate, current)
    [candidate.accessed_at, candidate.id] > [current.accessed_at, current.id]
  end

  def normalized_limit
    limit.positive? ? limit : DEFAULT_LIMIT
  end
end
