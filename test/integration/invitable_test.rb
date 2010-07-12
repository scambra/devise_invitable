require 'test/test_helper'

class InvitationTest < ActionController::IntegrationTest

  def send_invitation(&block)
    visit new_user_invitation_path

    assert_response :success
    assert_template 'invitations/new'
    assert warden.authenticated?(:user)

    fill_in 'email', :with => 'user@test.com'
    yield if block_given?
    click_button 'Send an invitation'
  end

  def set_password(options={}, &block)
    unless options[:visit] == false
      visit accept_user_invitation_path(:invitation_token => options[:invitation_token])
    end
    assert_response :success
    assert_template 'invitations/edit'

    fill_in 'Password', :with => '987654321'
    fill_in 'Password confirmation', :with => '987654321'
    yield if block_given?
    click_button 'Set my password'
  end

  test 'not authenticated user should not be able to send an invitation' do
    get new_user_invitation_path
    assert_not warden.authenticated?(:user)

    assert_redirected_to new_user_session_path(:unauthenticated => true)
  end

  test 'authenticated user should be able to send an invitation' do
    sign_in_as_user

    send_invitation
    assert_template 'home/index'
    assert_equal 'An email with instructions about how to set the password has been sent.', flash[:notice]
  end

  test 'authenticated user with invalid email should receive an error message' do
    user = create_user
    sign_in_as_user
    send_invitation do
      fill_in 'email', :with => user.email
    end

    assert_response :success
    assert_template 'invitations/new'
    assert_have_selector "input[type=text][value='#{user.email}']"
    assert_contain 'Email has already been taken'
  end

  test 'authenticated user should not be able to visit edit invitation page' do
    sign_in_as_user

    get accept_user_invitation_path

    assert_response :redirect
    assert_redirected_to root_path
    assert warden.authenticated?(:user)
  end

  test 'not authenticated user with invalid invitation token should not be able to set his password' do
    user = create_user
    set_password :invitation_token => 'invalid_token'

    assert_response :success
    assert_template 'invitations/edit'
    assert_have_selector '#errorExplanation'
    assert_contain 'Invitation token is invalid'
    assert_not user.reload.valid_password?('987654321')
  end

  test 'not authenticated user with valid invitation token but invalid password should not be able to set his password' do
    user = create_user(false)
    set_password :invitation_token => user.invitation_token do
      fill_in 'Password confirmation', :with => 'other_password'
    end

    assert_response :success
    assert_template 'invitations/edit'
    assert_have_selector '#errorExplanation'
    assert_contain 'Password doesn\'t match confirmation'
    assert_not user.reload.valid_password?('987654321')
  end

  test 'not authenticated user with valid data should be able to change his password' do
    user = create_user(false)
    set_password :invitation_token => user.invitation_token

    assert_template 'home/index'
    assert_equal 'Your password was set successfully. You are now signed in.', flash[:notice]
    assert user.reload.valid_password?('987654321')
  end

  test 'after entering invalid data user should still be able to set his password' do
    user = create_user(false)
    set_password :invitation_token => user.invitation_token do
      fill_in 'Password confirmation', :with => 'other_password'
    end
    assert_response :success
    assert_have_selector '#errorExplanation'
    assert_not user.reload.valid_password?('987654321')

    set_password :invitation_token => user.invitation_token
    assert_equal 'Your password was set successfully. You are now signed in.', flash[:notice]
    assert user.reload.valid_password?('987654321')
  end

  test 'sign in user automatically after setting it\'s password' do
    user = create_user(false)
    set_password :invitation_token => user.invitation_token

    assert warden.authenticated?(:user)
  end
end
