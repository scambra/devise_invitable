require 'test/test_helper'

class InvitableTest < ActiveSupport::TestCase

  def setup
    setup_mailer
  end

  test 'should not generate invitation token after creating a record' do
    assert_nil new_user.invitation_token
  end

  test 'should generate invitation token on invite' do
    user = new_user
    user.invite
    assert_not_nil user.invitation_token
  end

  test 'should persist new users on invite' do
    user = new_user
    user.invite
    assert user.persisted?
  end

  test 'should set additional accessible attributes on user.invite' do
    user = new_user(:name => "John Doe")
    user.invite
    assert_equal "John Doe", user.name
  end

  test 'should regenerate invitation token each time' do
    user = new_user
    3.times do
      token = user.invitation_token
      user.invite
      assert_not_equal token, user.invitation_token
    end
  end

  test 'should test invitation sent at with invite_for configuration value' do
    user = create_user_with_invitation('token')
    
    User.stubs(:invite_for).returns(nil)
    user.invitation_sent_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(nil)
    user.invitation_sent_at = 1.year.ago
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(0)
    user.invitation_sent_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(0)
    user.invitation_sent_at = 1.day.ago
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(1.day)
    user.invitation_sent_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(1.day)
    user.invitation_sent_at = 1.day.ago
    assert_not user.valid_invitation?
  end

  test 'should never generate the same invitation token for different users' do
    invitation_tokens = []
    3.times do
      user = new_user
      user.invite
      token = user.invitation_token
      assert !invitation_tokens.include?(token)
      invitation_tokens << token
    end
  end

  test 'should set password and password confirmation from params' do
    create_user_with_invitation('valid_token', :password => nil, :password_confirmation => nil)
    user = User.accept_invitation(:invitation_token => 'valid_token', :password => '123456789', :password_confirmation => '123456789')
    assert user.valid_password?('123456789')
  end

  test 'should set password and save the record' do
    user = create_user_with_invitation('valid_token', :password => nil, :password_confirmation => nil)
    old_encrypted_password = user.encrypted_password
    user = User.accept_invitation(:invitation_token => 'valid_token', :password => '123456789', :password_confirmation => '123456789')
    assert_not_equal old_encrypted_password, user.encrypted_password
  end

  test 'should clear invitation token while setting the password' do
    user = create_user_with_invitation('valid_token')
    assert_present user.invitation_token
    user.accept_invitation
    assert_nil user.invitation_token
  end

  test 'should not clear invitation token if record is invalid' do
    user = create_user_with_invitation('valid_token')
    assert_present user.invitation_token
    User.any_instance.stubs(:valid?).returns(false)
    User.accept_invitation(:invitation_token => 'valid_token', :password => '123456789', :password_confirmation => '987654321')
    user.reload
    assert_present user.invitation_token
  end

  test 'should reset invitation token and send invitation by email' do
    user = new_user
    assert_difference('ActionMailer::Base.deliveries.size') do
      token = user.invitation_token
      user.invite
      assert_not_equal token, user.invitation_token
    end
  end

  test 'should send invitation token and send invitation by email on invite' do
    user = new_user
    assert_difference('ActionMailer::Base.deliveries.size') do
      token = user.invitation_token
      user.invite
      assert_not_equal token, user.invitation_token
    end
  end

  test 'should not send invitation by email if invite is not valid' do
    user = new_user
    user.stubs(:valid?).returns(false)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      token = user.invitation_token
      user.invite
      assert_not_equal token, user.invitation_token
    end
  end

  # ===============
  # = User.invite =
  # ===============
  test 'should return a record with invitation token and no errors to send invitation by email' do
    invited_user = User.invite(:email => "valid@email.com")
    assert invited_user.errors.blank?
    assert_present invited_user.invitation_token
  end

  test 'should set additional accessible attributes on class invite' do
    invited_user = User.invite(:email => "valid@email.com", :name => "John Doe")
    assert_equal "John Doe", invited_user.name
  end

  test 'should return a record with errors if user is not valid on invite and User.validate_on_invite = true' do
    User.validate_on_invite = true
    invited_user = User.invite(:email => "valid@email.com", :name => "a"*50)
    assert_equal ["is too long (maximum is 20 characters)"], invited_user.errors[:name]
  end

  test 'should return a record with no errors if user is not valid on invite and User.validate_on_invite = false' do
    User.validate_on_invite = false
    invited_user = User.invite(:email => "valid@email.com", :name => "a"*50)
    assert_equal Hash.new, invited_user.errors
  end

  test 'should return a record with errors if user was found by e-mail' do
    user = create_user
    invited_user = User.invite(:email => user.email)
    assert_equal invited_user, user
    assert_equal ['has already been taken'], invited_user.errors[:email]
  end

  test 'should return a new record with errors if e-mail is nil' do
    invited_user = User.invite(:email => nil)
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:email]
  end

  test 'should return a new record with errors if e-mail is blank' do
    invited_user = User.invite(:email => '')
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:email]
  end

  test 'should return a new record with errors if e-mail is invalid' do
    invited_user = User.invite(:email => 'invalid_email')
    assert invited_user.new_record?
    assert_equal ["is invalid"], invited_user.errors[:email]
  end

  # ==========================
  # = User.accept_invitation =
  # ==========================
  test 'should find a user to set his password based on invitation_token' do
    user = new_user
    user.invite

    invited_user = User.accept_invitation(:invitation_token => user.invitation_token)
    assert_equal invited_user, user
  end

  test 'should return a new record with errors if no invitation_token is found' do
    invited_user = User.accept_invitation(:invitation_token => 'invalid_token')
    assert invited_user.new_record?
    assert_equal ['is invalid'], invited_user.errors[:invitation_token]
  end

  test 'should return a new record with errors if invitation_token is blank' do
    invited_user = User.accept_invitation(:invitation_token => '')
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:invitation_token]
  end

  test 'should return a new record with errors if invitation_token is nil' do
    invited_user = User.accept_invitation(:invitation_token => nil)
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:invitation_token]
  end

  test 'should return record with errors if invitation_token has expired' do
    user = create_user_with_invitation('valid_token')
    user.invitation_sent_at = 1.day.ago
    user.save
    User.stubs(:invite_for).returns(10.hours)
    invited_user = User.accept_invitation(:invitation_token => 'valid_token')
    assert_equal user, invited_user
    assert_equal ["is invalid"], invited_user.errors[:invitation_token]
  end

  test 'should return a record with errors if user is not valid on accept_invitation' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite

    invited_user = User.accept_invitation(
      :invitation_token => user.invitation_token,
      :password => 'new_password',
      :password_confirmation => 'new_password',
      :name => "a"*50
    )

    assert_equal ["is too long (maximum is 20 characters)"], invited_user.errors[:name]
  end

  test 'should set successfully user password given the new password and confirmation' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite

    invited_user = User.accept_invitation(
      :invitation_token => user.invitation_token,
      :password => 'new_password',
      :password_confirmation => 'new_password'
    )
    user.reload

    assert user.valid_password?('new_password')
  end
end
