class BaseController < ApplicationController
  def redirect_to_back(**options)
    redirect_back fallback_location: root_path, **options
  end
end
