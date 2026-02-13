require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  fixtures :users

  setup do
    @user = users(:one)
  end

  test "visiting root redirects to login when not authenticated" do
    visit root_path
    assert_current_path new_user_session_path
  end

  test "user can sign in with valid credentials" do
    visit new_user_session_path

    fill_in "Email", with: @user.email
    fill_in "Password", with: "password"
    click_button "Log in"

    assert_text "Signed in successfully"
    assert_current_path root_path
  end

  test "user cannot sign in with invalid password" do
    visit new_user_session_path

    fill_in "Email", with: @user.email
    fill_in "Password", with: "wrongpassword"
    click_button "Log in"

    assert_text "Invalid Email or password"
    assert_current_path new_user_session_path
  end

  test "user cannot sign in with non-existent email" do
    visit new_user_session_path

    fill_in "Email", with: "nonexistent@example.com"
    fill_in "Password", with: "password"
    click_button "Log in"

    assert_text "Invalid Email or password"
  end

  test "user can sign out" do
    sign_in_as(@user)
    assert_text "Signed in successfully"

    find("a.logout-icon").click

    assert_current_path new_user_session_path
  end
end
