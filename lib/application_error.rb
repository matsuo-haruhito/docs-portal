module ApplicationError
  class BadRequest < StandardError
  end

  class Unauthorized < StandardError
  end

  class Forbidden < StandardError
  end
end
