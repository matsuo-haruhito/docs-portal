class DocumentHistoryStatusPresenter
  STATUS_LABELS = {
    canonical: "現在の場所",
    moved: "移動済み",
    missing: "未解決",
    archived: "アーカイブ済み",
    deleted: "削除済み"
  }.freeze

  STATUS_MESSAGES = {
    canonical: "このURLは現在の文書位置です。",
    moved: "旧URLから現在の文書位置へ移動しました。",
    missing: "このURLに対応する現在の文書位置は見つかりませんでした。",
    archived: "このURLに対応する文書はアーカイブ済みです。",
    deleted: "このURLに対応する文書は削除済みです。"
  }.freeze

  attr_reader :status, :requested_value, :canonical_value

  def initialize(status:, requested_value: nil, canonical_value: nil)
    @status = status.to_sym
    @requested_value = requested_value
    @canonical_value = canonical_value
  end

  def label
    STATUS_LABELS.fetch(status, STATUS_LABELS.fetch(:missing))
  end

  def message
    STATUS_MESSAGES.fetch(status, STATUS_MESSAGES.fetch(:missing))
  end

  def warning?
    %i[missing archived deleted].include?(status)
  end

  def moved?
    status == :moved
  end

  def canonical?
    status == :canonical
  end

  def detail
    return if requested_value.blank? && canonical_value.blank?
    return requested_value if canonical_value.blank? || requested_value == canonical_value

    "#{requested_value} -> #{canonical_value}"
  end
end
