require "test_helper"

class Admin::UsageControllerTest < ActionDispatch::IntegrationTest
  test "a non-admin has no access to the usage dashboard" do
    sign_in users(:regular)

    get admin_usage_url

    assert_redirected_to root_url
  end
end
