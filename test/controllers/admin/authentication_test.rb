require "test_helper"

# Overview §4.7: every /admin route requires login. The routes are read from the route set, so a new
# admin route is covered without touching this test.
class Admin::AuthenticationTest < ActionDispatch::IntegrationTest
  test "every admin route sends a signed-out visitor to the login" do
    routes = Rails.application.routes.routes.select { |route| route.path.spec.to_s.start_with?("/admin") }
    assert_operator routes.size, :>=, 2

    routes.each do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:\w+/, "1")

      route.verb.split("|").each do |verb|
        process verb.downcase.to_sym, path

        assert_redirected_to new_session_url, "#{verb} #{path} must require login"
      end
    end
  end

  test "a signed-out visitor never sees an admin page" do
    get admin_root_path

    assert_redirected_to new_session_url
    assert_no_match "Obras", response.body
  end
end
