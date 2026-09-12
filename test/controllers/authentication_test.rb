require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated visitors are redirected to sign in" do
    get root_url

    assert_redirected_to new_user_session_url
  end

  test "the health check stays public" do
    get "/up"

    assert_response :success
  end
end
