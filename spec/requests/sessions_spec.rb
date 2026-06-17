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

  describe "GET /capture_login" do
    it "is not routed in the test environment" do
      expect do
        get "/capture_login"
      end.to raise_error(ActionController::RoutingError)
    end

    context "when the development-only route is drawn" do
      around do |example|
        with_routing do |set|
          set.draw do
            root "projects#index"
            get "capture_login", to: "sessions#capture_login"
          end

          example.run
        end
      end

      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it "signs in an active user and preserves an internal redirect path" do
        previous_login_at = 2.days.ago
        user = create(:user, email_address: "Seed.User@example.com", last_login_at: previous_login_at)

        get "/capture_login", params: { email: "seed.user@example.com", redirect: "/dashboard" }

        expect(response).to redirect_to("/dashboard")
        expect(request.session[:user_id]).to eq(user.id)
        expect(user.reload.last_login_at).to be > previous_login_at
      end

      it "rejects inactive users before creating a login session" do
        previous_login_at = 2.days.ago
        user = create(:user, active: false, last_login_at: previous_login_at)

        expect do
          get "/capture_login", params: { email: user.email_address, redirect: "/dashboard" }
        end.to raise_error(ActiveRecord::RecordNotFound, "Inactive user")

        expect(user.reload.last_login_at.to_i).to eq(previous_login_at.to_i)
      end

      it "rejects unknown email addresses before creating a login session" do
        user = create(:user, last_login_at: 2.days.ago)

        expect do
          get "/capture_login", params: { email: "missing@example.com", redirect: "/dashboard" }
        end.to raise_error(ActiveRecord::RecordNotFound)

        expect(user.reload.last_login_at.to_i).to eq(2.days.ago.to_i).or be < 1.day.ago.to_i
      end

      it "rejects external and invalid redirect values" do
        unsafe_redirects = [
          "https://example.com/dashboard",
          "//example.com/dashboard",
          "http://[example"
        ]

        unsafe_redirects.each do |redirect|
          user = create(:user)

          expect do
            get "/capture_login", params: { email: user.email_address, redirect: redirect }
          end.to raise_error(ActionController::RoutingError, "Invalid redirect")
        end
      end

      it "keeps the action guarded when the route is reachable outside development" do
        allow(Rails.env).to receive(:development?).and_return(false)
        user = create(:user)

        expect do
          get "/capture_login", params: { email: user.email_address, redirect: "/dashboard" }
        end.to raise_error(ActionController::RoutingError, "Not Found")

        expect(user.reload.last_login_at).to be_nil
      end
    end
  end
end
