class Admin::ConsentTermsController < Admin::BaseController
  CONSENT_TERM_QUERY_MAX_LENGTH = 100
  CONSENT_TERMS_DEFAULT_PER_PAGE = 25
  CONSENT_TERMS_MAX_PER_PAGE = 100

  before_action :require_admin_only!
  before_action :set_consent_term, only: %i[edit update destroy]

  def index
    load_consent_terms
    @consent_term = ConsentTerm.new(active: true, consent_scope: :project, requirement_timing: :first_view)
  end

  def create
    @consent_term = ConsentTerm.new(consent_term_params)

    if @consent_term.save
      redirect_to admin_consent_terms_path, notice: "同意文面を登録しました。"
    else
      load_consent_terms
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @consent_term.update(consent_term_params)
      redirect_to admin_consent_terms_path, notice: "同意文面を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @consent_term.destroy!
    redirect_to admin_consent_terms_path, notice: "同意文面を削除しました。"
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
    redirect_to admin_consent_terms_path, alert: "関連データがあるため削除できません。無効化してください。"
  end

  private

  def load_consent_terms
    @consent_term_filters = consent_term_filter_params
    @consent_term_filters_applied = @consent_term_filters.values.any?(&:present?)
    @consent_terms_exist = ConsentTerm.exists?

    ordered_consent_terms = filtered_consent_terms.order(:title, :version_label)
    @consent_terms_total_count = ordered_consent_terms.count
    @consent_terms_per_page = normalized_consent_terms_per_page
    @consent_terms_total_pages = [(@consent_terms_total_count.to_f / @consent_terms_per_page).ceil, 1].max
    @consent_terms_page = normalized_consent_terms_page(@consent_terms_total_pages)
    @consent_terms_offset = (@consent_terms_page - 1) * @consent_terms_per_page
    @consent_terms = ordered_consent_terms.offset(@consent_terms_offset).limit(@consent_terms_per_page).to_a
    @consent_terms_display_start = @consent_terms_total_count.zero? ? 0 : @consent_terms_offset + 1
    @consent_terms_display_end = @consent_terms_offset + @consent_terms.size
    @consent_terms_has_previous_page = @consent_terms_page > 1
    @consent_terms_has_next_page = @consent_terms_offset + @consent_terms.size < @consent_terms_total_count
  end

  def filtered_consent_terms
    ConsentTerm.all
      .then { |scope| apply_query_filter(scope) }
      .then { |scope| apply_active_filter(scope) }
      .then { |scope| apply_enum_filter(scope, :consent_scope, ConsentTerm.consent_scopes) }
      .then { |scope| apply_enum_filter(scope, :requirement_timing, ConsentTerm.requirement_timings) }
  end

  def apply_query_filter(scope)
    query = @consent_term_filters[:q].to_s
    return scope if query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.where("title ILIKE :query OR version_label ILIKE :query", query: pattern)
  end

  def apply_active_filter(scope)
    case @consent_term_filters[:active]
    when "true"
      scope.where(active: true)
    when "false"
      scope.where(active: false)
    else
      scope
    end
  end

  def apply_enum_filter(scope, attribute, enum_values)
    value = @consent_term_filters[attribute]
    return scope unless enum_values.key?(value)

    scope.where(attribute => value)
  end

  def consent_term_filter_params
    filters = params.permit(:q, :active, :consent_scope, :requirement_timing).to_h.symbolize_keys
    filters[:q] = normalized_consent_term_query(filters[:q])
    filters
  end

  def normalized_consent_term_query(value)
    query = value.to_s.squish.presence

    query&.slice(0, CONSENT_TERM_QUERY_MAX_LENGTH)
  end

  def normalized_consent_terms_per_page
    requested_per_page = params[:per_page].to_i
    per_page = requested_per_page.positive? ? requested_per_page : CONSENT_TERMS_DEFAULT_PER_PAGE

    [per_page, CONSENT_TERMS_MAX_PER_PAGE].min
  end

  def normalized_consent_terms_page(total_pages)
    requested_page = params[:page].to_i
    page = requested_page.positive? ? requested_page : 1

    page > total_pages ? 1 : page
  end

  def set_consent_term
    @consent_term = ConsentTerm.find_by!(public_id: params[:public_id])
  end

  def consent_term_params
    params.require(:consent_term).permit(:title, :body, :version_label, :consent_scope, :requirement_timing, :active)
  end
end