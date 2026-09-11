require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "a non-admin has no access to the user admin screen" do
    sign_in users(:regular)

    get admin_users_url

    assert_redirected_to root_url
  end

  test "an admin can create a user; a blank password defaults to the email" do
    sign_in users(:admin)

    assert_difference("User.count", 1) do
      post admin_users_url, params: {
        user: { email: "new@flex.com", roles: "admin", password: "", password_confirmation: "" }
      }
    end

    user = User.find_by(email: "new@flex.com")
    assert user.valid_password?("new@flex.com")
    assert user.has_role?(:admin)
  end

  test "an admin can edit a user; a blank password keeps the current one" do
    sign_in users(:admin)
    user = users(:regular)

    patch admin_user_url(user), params: {
      user: { email: user.email, roles: "user", password: "", password_confirmation: "" }
    }

    assert_redirected_to admin_users_url
    assert user.reload.valid_password?("password123")
  end

  test "an admin can delete another user but not themself" do
    sign_in users(:admin)

    assert_difference("User.count", -1) do
      delete admin_user_url(users(:regular))
    end

    assert_no_difference("User.count") do
      delete admin_user_url(users(:admin))
    end
  end
end
