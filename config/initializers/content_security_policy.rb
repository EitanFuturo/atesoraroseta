# Be sure to restart your server when you modify this file.

# Application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    # Inline styles are needed for the per-tile sizes on public pages and for the editor.
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self, :data, :blob
    policy.font_src        :self
    policy.connect_src     :self
    policy.object_src      :none
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  # A fresh random nonce per request, for script-src only (the importmap and any inline script).
  # It does not come from the session, so rendering a page never writes a session cookie.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
