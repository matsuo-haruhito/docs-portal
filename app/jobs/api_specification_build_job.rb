class ApiSpecificationBuildJob < ApplicationJob
  queue_as :default

  def perform
    Admin::ApiSpecificationPage.new.build!
  ensure
    Admin::ApiSpecificationPage.new.clear_build_request!
  end
end
