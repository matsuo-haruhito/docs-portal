# frozen_string_literal: true

class ListFooterComponent < ViewComponent::Base
  renders_many :exports

  def initialize(pagination:, url:, params: {}, page_param: :page, label: "一覧ページ", anchor: nil)
    @pagination = pagination.symbolize_keys
    @url = url
    @params = params.to_h.stringify_keys.except(page_param.to_s)
    @page_param = page_param.to_sym
    @label = label
    @anchor = anchor.to_s.presence
  end

  def current_page
    @pagination.fetch(:page).to_i
  end

  def total_pages
    @pagination.fetch(:total_pages).to_i
  end

  def total_count
    @pagination.fetch(:total_count).to_i
  end

  def paginated?
    total_pages > 1
  end

  def range_label
    return "0 / 0件" if total_count.zero?

    "#{@pagination.fetch(:from)}–#{@pagination.fetch(:to)} / #{total_count}件"
  end

  def page_numbers
    return (1..total_pages).to_a if total_pages <= 7

    middle = ((current_page - 2)..(current_page + 2)).select { |page| page.between?(1, total_pages) }
    [1, *middle, total_pages].uniq.sort
  end

  def page_path(page)
    query_params = @params.merge(@page_param.to_s => page).sort.to_h
    query = Rack::Utils.build_nested_query(query_params)
    path = if query.blank?
      @url
    else
      separator = @url.include?("?") ? "&" : "?"
      "#{@url}#{separator}#{query}"
    end
    anchored_path(path)
  end

  def form_url
    anchored_path(@url)
  end

  def previous_page_cue
    "#{@label}の#{current_page - 1}ページ目へ戻る（#{total_pages}ページ中）"
  end

  def next_page_cue
    "#{@label}の#{current_page + 1}ページ目へ進む（#{total_pages}ページ中）"
  end

  def hidden_params
    @params.flat_map do |key, value|
      Array(value).filter_map { |item| [key, item] if item.present? }
    end
  end

  private

  def anchored_path(path)
    return path if @anchor.blank?

    "#{path}##{@anchor}"
  end
end
