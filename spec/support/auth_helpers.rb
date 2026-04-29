module AuthHelpers
  def sign_in_as(user, password: "password123!")
    post session_path, params: {
      session: {
        email_address: user.email_address,
        password:
      }
    }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
