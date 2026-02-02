require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :users

  test "fixture is valid" do
    assert users(:one).valid?
  end

  test "requires email" do
    u = User.new(email: "", password: "password123", password_confirmation: "password123")
    assert_not u.valid?
    assert u.errors[:email].any?
  end

  test "email must be unique" do
    u = User.new(email: users(:one).email, password: "password123", password_confirmation: "password123")
    assert_not u.valid?
    assert u.errors[:email].any?
  end

  test "valid with email and password" do
    u = User.new(email: "nuevo@test.example.com", password: "password123", password_confirmation: "password123")
    assert u.valid?
  end
end
