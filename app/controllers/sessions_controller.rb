# The admin's login. There is no sign-up and no password recovery: the password comes from the
# encrypted credentials (bin/rails admin:credentials, then admin:sync or a deploy).
class SessionsController < ApplicationController
  include Admin::BrowserSupport

  layout "admin"

  allow_unauthenticated_access only: %i[ new create ]
  # 5 attempts per 10 minutes per IP, counted in the app's cache store (Solid Cache in production).
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: t(".rate_limited") }

  def new
    redirect_to admin_root_url if authenticated?
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: t(".invalid")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: t(".notice"), status: :see_other
  end
end
