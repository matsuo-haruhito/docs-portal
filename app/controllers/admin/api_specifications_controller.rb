class Admin::ApiSpecificationsController < Admin::BaseController
  before_action :require_admin_only!

  def show
    @api_specification_page = Admin::ApiSpecificationPage.new(view_context:)
  end

  def site
    page = Admin::ApiSpecificationPage.new(view_context:)
    raise ActiveRecord::RecordNotFound unless page.available?

    render html: page.render_site(params[:site_path]).html_safe, layout: false
  end
end
