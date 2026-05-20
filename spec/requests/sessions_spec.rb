require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /projects" do
    it "redirects unauthenticated user to login" do
      get projects_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "session lifecycle" do
    it "logs in and logs out successfully" do
      user = create(:user)

      sign_in_as(user)

      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response.body).to include("ログアウト")

      delete session_path

      expect(response).to redirect_to(new_session_path)
    end

    it "rejects inactive users" do
      user = create(:user, active: false)

      post session_path, params: {
        session: {
          email_address: user.email_address,
          password: "password123!"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("メールアドレスまたはパスワードが正しくありません。")
    end
  end
end