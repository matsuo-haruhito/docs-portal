class AccessRequestHash
  def initialize(access_request)
    @access_request = access_request
  end

  def call
    AccessRequestPresentation::HashBuilder.new(access_request:).call
  end

  private

  attr_reader :access_request
end
