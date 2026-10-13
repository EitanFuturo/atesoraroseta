class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Checked only when a password is being set; has_secure_password already caps it at 72 bytes.
  validates :password, length: { minimum: 12 }, allow_nil: true
end
