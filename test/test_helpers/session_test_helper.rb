# sign_in_as(user) and sign_out for integration and system tests.
#
# Both create a real Session row and hand its signed id to the client as the "session_id" cookie,
# exactly as SessionsController#create does, without going through the login form.
module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

# System tests drive a real browser, so the cookie goes into the browser. Selenium only sets cookies
# for the page it is on, hence the visit to /up first.
module SystemSessionTestHelper
  def sign_in_as(user)
    session = user.sessions.create!
    signed_id = ActionDispatch::TestRequest.create.cookie_jar.tap { |jar| jar.signed[:session_id] = session.id }[:session_id]

    visit rails_health_check_path
    page.driver.browser.manage.add_cookie(
      name: "session_id", value: Rack::Utils.escape(signed_id), path: "/", http_only: true, same_site: "Lax"
    )
    session
  end

  def sign_out
    page.driver.browser.manage.delete_cookie("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end

ActiveSupport.on_load(:action_dispatch_system_test_case) do
  include SystemSessionTestHelper
end
