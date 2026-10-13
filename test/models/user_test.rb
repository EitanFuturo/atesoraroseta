require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects a password shorter than 12 characters, in Spanish" do
    user = User.new(email_address: "corta@example.com", password: "a" * 11)

    assert_not user.valid?
    assert_includes user.errors.full_messages, "Contraseña es demasiado corta (12 caracteres mínimo)"
  end

  test "accepts a password of 12 characters or more" do
    user = User.new(email_address: "larga@example.com", password: "a" * 12)

    assert user.valid?
  end

  test "does not check the length when the password is not being changed" do
    user = users(:one)
    user.email_address = "otro@example.com"

    assert user.valid?
  end
end
