require 'test_helper'
require 'model_tests_helper'

class InvitableTest < ActiveSupport::TestCase

  def setup
    setup_mailer
  end

  test 'should not generate invitation token after creating a record' do
    assert_nil new_user.invitation_token
  end

  test 'should update the invitations count counter cache' do
    if defined?(ActiveRecord)
      current_user = new_user
      2.times do |index|
        User.invite!({:email => "valid#{index}@email.com"}, current_user)
      end
      assert_equal current_user.reload.invitations_count, 2
    end
  end

  test 'should not generate the raw invitation token after creating a record' do
    assert_nil new_user.raw_invitation_token
  end

  test 'should regenerate invitation token each time' do
    user = new_user
    user.invite!

    assert_not_nil user.invitation_token
    assert_not_nil user.raw_invitation_token
    assert_not_nil user.invitation_created_at

    3.times do
      user = User.find(user.id)

      assert_not_same user.invitation_token, lambda {
        user.invite!
        user.invitation_token
      }.call
      assert_not_nil user.raw_invitation_token
    end
  end

  test 'should regenerate invitation token each time even if "skip_invitation" was true' do
    user = new_user
    user.skip_invitation = true
    user.invite!

    assert_not_nil user.invitation_token
    assert_not_nil user.invitation_created_at

    3.times do
      user = User.find(user.id)
      user.skip_invitation = true

      assert_not_same user.invitation_token, lambda {
        user.invite!
        user.invitation_token
      }.call
      assert_not_nil user.invitation_token
      assert_not_nil user.raw_invitation_token
    end
  end

  test 'should alias the invitation_token method with encrypted_invitation_token' do
    user = new_user
    user.invite!
    assert_equal user.invitation_token, user.encrypted_invitation_token
  end

  test 'should return the correct raw_invitation_token ' do
    user = new_user
    raw, enc = Devise.token_generator.generate(user.class, :invitation_token)
    #stub the generator so the tokens are the same
    Devise.token_generator.stubs(:generate).returns([raw, enc])
    user.invite!
    assert_equal user.raw_invitation_token, raw
  end

  test 'should set invitation created and sent at each time' do
    user = new_user
    user.invite!
    old_invitation_created_at = 3.days.ago
    old_invitation_sent_at = 3.days.ago
    user.update_attributes(:invitation_sent_at => old_invitation_sent_at, :invitation_created_at => old_invitation_created_at)
    3.times do
      user.invite!
      assert_not_equal old_invitation_sent_at, user.invitation_sent_at
      assert_not_equal old_invitation_created_at, user.invitation_created_at
      user.update_attributes(:invitation_sent_at => old_invitation_sent_at, :invitation_created_at => old_invitation_created_at)
    end
  end

  test 'should test invitation sent at with invite_for configuration value' do
    user = User.invite!(:email => "valid@email.com")

    User.stubs(:invite_for).returns(nil)
    user.invitation_created_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(nil)
    user.invitation_created_at = 1.year.ago
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(0)
    user.invitation_created_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(0)
    user.invitation_created_at = 1.day.ago
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(1.day)
    user.invitation_created_at = Time.now.utc
    assert user.valid_invitation?

    User.stubs(:invite_for).returns(1.day)
    user.invitation_created_at = 2.days.ago
    assert !user.valid_invitation?
  end

  test 'should never generate the same invitation token for different users' do
    invitation_tokens = []
    3.times do
      user = new_user
      user.invite!
      token = user.invitation_token
      assert !invitation_tokens.include?(token)
      invitation_tokens << token
    end
  end

  test 'should invite with multiple columns for invite key' do
    User.stubs(:invite_key).returns(:email => Devise.email_regexp, :username => /\A.+\z/)
    user = User.invite!(:email => "valid@email.com", :username => "name")
    assert user.persisted?
    assert user.errors.empty?
  end

  test 'should allow non-string columns for invite key' do
    User.stubs(:invite_key).returns(:email => Devise.email_regexp, :profile_id => :present?.to_proc, :active => true)
    user = User.invite!(:email => "valid@email.com", :profile_id => 1, :active => true)
    assert user.persisted?
    assert user.errors.empty?
  end

  test 'should not invite with some missing columns when invite key is an array' do
    User.stubs(:invite_key).returns(:email => Devise.email_regexp, :username => /\A.+\z/, :profile_id => :present?.to_proc, :active => true)
    user = User.invite!(:email => "valid@email.com")
    assert user.new_record?
    assert user.errors.present?
    assert user.errors[:username]
    assert user.errors[:profile_id]
    assert user.errors[:active]
    assert user.errors[:email].empty?
  end

  test 'should return mail object' do
    mail = User.invite_mail!(:email => 'valid@email.com')
    assert mail.class.name == 'Mail::Message'
  end

  test 'should disallow login when invited' do
    invited_user = User.invite!(:email => "valid@email.com")
    assert !invited_user.valid_password?('1234')
  end

  test 'should set password and password confirmation from params' do
    User.invite!(:email => "valid@email.com")
    user = User.accept_invitation!(:invitation_token => Thread.current[:token], :password => '123456789', :password_confirmation => '123456789')
    assert user.valid_password?('123456789')
  end

  test 'should set password and save the record' do
    user = User.invite!(:email => "valid@email.com")
    old_encrypted_password = user.encrypted_password
    user = User.accept_invitation!(:invitation_token => Thread.current[:token], :password => '123456789', :password_confirmation => '123456789')
    assert_not_equal old_encrypted_password, user.encrypted_password
  end

  test 'should clear invitation token and set invitation_accepted_at while accepting the password' do
    user = User.invite!(:email => "valid@email.com")
    assert user.invitation_token.present?
    assert_nil user.invitation_accepted_at
    user.accept_invitation!
    user.reload
    assert_nil user.invitation_token
    assert user.invitation_accepted_at.present?
  end

  test 'should not clear invitation token or set accepted_at if record is invalid' do
    user = User.invite!(:email => "valid@email.com")
    assert user.invitation_token.present?
    assert_nil user.invitation_accepted_at
    User.accept_invitation!(:invitation_token => user.invitation_token, :password => '123456789', :password_confirmation => '987654321')
    user.reload
    assert user.invitation_token.present?
    assert_nil user.invitation_accepted_at
  end

  test 'should clear invitation token while resetting the password' do
    user = User.invite!(:email => "valid@email.com")
    assert user.invited_to_sign_up?
    token, user.reset_password_token = Devise.token_generator.generate(User, :reset_password_token)
    user.reset_password_sent_at = Time.now.utc
    user.save

    assert user.reset_password_token.present?
    assert user.invitation_token.present?
    User.reset_password_by_token(:reset_password_token => token, :password => '123456789', :password_confirmation => '123456789')
    assert_nil user.reload.reset_password_token
    assert_nil user.reload.invitation_token
    assert !user.invited_to_sign_up?
  end

  test 'should not accept invitation on failing to reset the password' do
    user = User.invite!(:email => "valid@email.com")
    assert user.invited_to_sign_up?
    token, user.reset_password_token = Devise.token_generator.generate(User, :reset_password_token)
    user.reset_password_sent_at = Time.now.utc
    user.save

    assert user.reset_password_token.present?
    assert user.invitation_token.present?
    User.reset_password_by_token(:reset_password_token => token, :password => '123456789', :password_confirmation => '12345678')
    assert user.reload.reset_password_token.present?
    assert user.reload.invitation_token.present?
    assert user.invited_to_sign_up?
  end

  test 'should not set invitation_accepted_at if just resetting password' do
    user = User.create!(:email => "valid@email.com", :password => "123456780")
    assert !user.invited_to_sign_up?
    token, user.reset_password_token = Devise.token_generator.generate(User, :reset_password_token)
    user.reset_password_sent_at = Time.now.utc
    user.save

    assert user.reset_password_token.present?
    assert_nil user.invitation_token
    User.reset_password_by_token(:reset_password_token => token, :password => '123456789', :password_confirmation => '123456789')
    assert_nil user.reload.invitation_token
    assert_nil user.reload.invitation_accepted_at
  end

  test 'should reset invitation token and send invitation by email' do
    user = new_user
    assert_difference('ActionMailer::Base.deliveries.size') do
      token = user.invitation_token
      user.invite!
      assert_not_equal token, user.invitation_token
    end
  end

  test 'should return a record with invitation token and no errors to send invitation by email' do
    invited_user = User.invite!(:email => "valid@email.com")
    assert invited_user.errors.blank?
    assert invited_user.invitation_token.present?
    assert_equal 'valid@email.com', invited_user.email
    assert invited_user.persisted?
  end

  test 'should set all attributes with no errors' do
    invited_user = User.invite!(:email => "valid@email.com", :username => 'first name')
    assert invited_user.errors.blank?
    assert_equal 'first name', invited_user.username
    assert invited_user.persisted?
  end

  test 'should not validate other attributes when validate_on_invite is disabled' do
    validate_on_invite = User.validate_on_invite
    User.validate_on_invite = false
    invited_user = User.invite!(:email => "valid@email.com", :username => "a"*50)
    assert invited_user.errors.empty?
    User.validate_on_invite = validate_on_invite
  end

  test 'should validate other attributes when validate_on_invite is enabled' do
    validate_on_invite = User.validate_on_invite
    User.validate_on_invite = true
    invited_user = User.invite!(:email => "valid@email.com", :username => "a"*50)
    assert invited_user.errors[:username].present?
    User.validate_on_invite = validate_on_invite
  end

  test 'should not validate password when validate_on_invite is enabled' do
    validate_on_invite = User.validate_on_invite
    User.validate_on_invite = true
    invited_user = User.invite!(:email => "valid@email.com", :username => "a"*50)
    assert invited_user.errors.present?
    assert invited_user.errors[:password].empty?
    User.validate_on_invite = validate_on_invite
  end

  test 'should validate other attributes when validate_on_invite is enabled and email is not present' do
    validate_on_invite = User.validate_on_invite
    User.validate_on_invite = true
    invited_user = User.invite!(:email => "", :username => "a"*50)
    assert invited_user.errors[:email].present?
    assert invited_user.errors[:username].present?
    User.validate_on_invite = validate_on_invite
  end

  test 'should return a record with errors if user was found by e-mail' do
    existing_user = User.new(:email => "valid@email.com")
    existing_user.save(:validate => false)
    user = User.invite!(:email => "valid@email.com")
    assert_equal user, existing_user
    assert_equal ['has already been taken'], user.errors[:email]
    same_user = User.invite!("email" => "valid@email.com")
    assert_equal same_user, existing_user
    assert_equal ['has already been taken'], same_user.errors[:email]
  end

  test 'should return a record with errors if user with pending invitation was found by e-mail' do
    existing_user = User.invite!(:email => "valid@email.com")
    user = User.invite!(:email => "valid@email.com")
    assert_equal user, existing_user
    assert_equal [], user.errors[:email]
    resend_invitation = User.resend_invitation
    begin
      User.resend_invitation = false

      user = User.invite!(:email => "valid@email.com")
      assert_equal user, existing_user
      assert_equal ['has already been taken'], user.errors[:email]
    ensure
      User.resend_invitation = resend_invitation
    end
  end

  test 'should return a record with errors if user was found by e-mail with validate_on_invite' do
    begin
      validate_on_invite = User.validate_on_invite
      User.validate_on_invite = true
      existing_user = User.new(:email => "valid@email.com")
      existing_user.save(:validate => false)
      user = User.invite!(:email => "valid@email.com", :username => "a"*50)
      assert_equal user, existing_user
      assert_equal ['has already been taken'], user.errors[:email]
      assert user.errors[:username].present?
    ensure
      User.validate_on_invite = validate_on_invite
    end
  end

  test 'should return a new record with errors if e-mail is blank' do
    invited_user = User.invite!(:email => '')
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:email]
  end

  test 'should return a new record with errors if e-mail is invalid' do
    invited_user = User.invite!(:email => 'invalid_email')
    assert invited_user.new_record?
    assert_equal ["is invalid"], invited_user.errors[:email]
  end

  test 'should set all attributes with errors if e-mail is invalid' do
    invited_user = User.invite!(:email => "invalid_email.com", :username => 'first name')
    assert invited_user.new_record?
    assert_equal 'first name', invited_user.username
    assert invited_user.errors.present?
  end

  test 'should find a user to set his password based on invitation_token' do
    user = new_user
    user.invite!
    invited_user = User.accept_invitation!(:invitation_token => Thread.current[:token])
    assert_equal invited_user, user
  end

  test 'should return a new record with errors if no invitation_token is found' do
    invited_user = User.accept_invitation!(:invitation_token => 'invalid_token')
    assert invited_user.new_record?
    assert_equal ['is invalid'], invited_user.errors[:invitation_token]
  end

  test 'should return a new record with errors if invitation_token is blank' do
    invited_user = User.accept_invitation!(:invitation_token => '')
    assert invited_user.new_record?
    assert_equal ["can't be blank"], invited_user.errors[:invitation_token]
  end

  test 'should return record with errors if invitation_token has expired' do
    User.stubs(:invite_for).returns(10.hours)
    invited_user = User.invite!(:email => "valid@email.com")
    invited_user.invitation_created_at = 2.days.ago
    invited_user.save(:validate => false)
    user = User.accept_invitation!(:invitation_token => Thread.current[:token])
    assert_equal user, invited_user
    assert_equal ["is invalid"], user.errors[:invitation_token]
  end

  test 'should allow record modification using block' do
    invited_user = User.invite!(:email => "valid@email.com", :username => "a"*50) do |u|
      u.password = '123123'
      u.password_confirmation = '123123'
    end
    assert_equal '123123', invited_user.reload.password
  end

  test 'should set successfully user password given the new password and confirmation' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite!

    User.accept_invitation!(
      :invitation_token => Thread.current[:token],
      :password => 'new_password',
      :password_confirmation => 'new_password'
    )
    user.reload

    assert user.valid_password?('new_password')
  end

  test 'should return errors on other attributes even when password is valid' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite!

    invited_user = User.accept_invitation!(
      :invitation_token => Thread.current[:token],
      :password => 'new_password',
      :password_confirmation => 'new_password',
      :username => 'a'*50
    )
    assert invited_user.errors[:username].present?

    user.reload
    assert !user.valid_password?('new_password')
  end

  test 'should set other attributes on accepting invitation' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite!

    invited_user = User.accept_invitation!(
      :invitation_token => Thread.current[:token],
      :password => 'new_password',
      :password_confirmation => 'new_password',
      :username => 'a'
    )
    assert invited_user.errors[:username].blank?

    user.reload
    assert_equal 'a', user.username
    assert user.valid_password?('new_password')
  end

  test 'should not confirm user on invite' do
    user = new_user

    user.invite!

    assert !user.confirmed?
  end

  test 'user.has_invitations_left? test' do
    # By default with invitation_limit nil, users can send unlimited invitations
    user = new_user
    assert_nil user.invitation_limit
    assert user.has_invitations_left?

    # With invitation_limit set to a value, all users can send that many invitations
    User.stubs(:invitation_limit).returns(2)
    assert user.has_invitations_left?

    # With an individual invitation_limit of 0, a user shouldn't be able to send an invitation
    user.invitation_limit = 0
    assert user.save
    assert !user.has_invitations_left?

    # With in invitation_limit of 2, a user should be able to send two invitations
    user.invitation_limit = 2
    assert user.save
    assert user.has_invitations_left?
  end

  test 'should not send an invitation if we want to skip the invitation' do
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      User.invite!(:email => "valid@email.com", :username => "a"*50, :skip_invitation => true)
    end
  end

  test 'should not send an invitation if we want to skip the invitation with block' do
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      User.invite!(:email => "valid@email.com", :username => "a"*50) do |u|
        u.skip_invitation = true
      end
    end
  end

  test 'user.invite! should not send an invitation if we want to skip the invitation' do
    user = new_user
    user.skip_invitation = true
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.invite!
    end
    assert user.invitation_created_at.present?
    assert_nil user.invitation_sent_at
  end

  test 'user.invite! should not send an invitation if we want to skip the invitation with block' do
    user = new_user
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      user.invite! do |u|
        u.skip_invitation = true
      end
    end
    assert user.invitation_created_at.present?
    assert_nil user.invitation_sent_at
  end

  test 'user.invite! should not set the invited_by attribute if not passed' do
    user = new_user
    user.invite!
    assert_equal nil, user.invited_by
  end

  test 'user.invite! should set the invited_by attribute if passed' do
    user = new_user
    inviting_user = User.new(:email => "valid@email.com")
    inviting_user.save(:validate => false)
    user.invite!(inviting_user)
    assert_equal inviting_user, user.invited_by
    assert_equal inviting_user.class.to_s, user.invited_by_type
  end

  test 'user.accept_invitation! should trigger callbacks' do
    user = User.invite!(:email => "valid@email.com")
    assert_callbacks_not_fired user
    user.accept_invitation!
    assert_callbacks_fired user
  end

  test 'user.accept_invitation! should not trigger callbacks if validation fails' do
    user = User.invite!(:email => "valid@email.com")
    assert_callbacks_not_fired user
    user.username='a'*50
    user.accept_invitation!
    assert_callbacks_not_fired user
  end

  test 'user.accept_invitation! should confirm user if confirmable' do
    user = User.invite!(:email => "valid@email.com")
    user.accept_invitation!

    assert user.confirmed?
  end

  test 'user.accept_invitation! should not confirm user if validation fails' do
    user = User.invite!(:email => "valid@email.com")
    user.username='a'*50
    user.accept_invitation!

    assert !user.confirmed?
  end

  def assert_callbacks_fired(user)
    assert_callbacks_status user, true
  end

  def assert_callbacks_not_fired(user)
    assert_callbacks_status user, nil
  end

  def assert_callbacks_status(user, fired)
    assert_equal fired, user.callback_works
  end

  test "user.invite! should downcase the class's case_insensitive_keys" do
    # Devise default is :email
    user = User.invite!(:email => "UPPERCASE@email.com")
    assert user.email == "uppercase@email.com"
  end

  test "user.invite! should strip whitespace from the class's strip_whitespace_keys" do
    # Devise default is email
    user = User.invite!(:email => " valid@email.com ", :active => true)
    assert user.email == "valid@email.com"
    assert user.active == true
  end

  test 'should pass validation before accept if field is required in post-invited instance' do
    user = User.invite!(:email => "valid@email.com")
    user.testing_accepted_or_not_invited = true
    assert_equal true, user.valid?
  end

  test 'should fail validation after accept if field is required in post-invited instance' do
    user = User.invite!(:email => "valid@email.com")
    user.testing_accepted_or_not_invited = true
    user.accept_invitation!
    assert_equal false, user.valid?
  end

  test 'should pass validation after accept if field is required in post-invited instance' do
    user = User.invite!(:email => "valid@email.com")
    user.username = 'test'
    user.testing_accepted_or_not_invited = true
    user.bio = "Test"
    user.accept_invitation!
    assert_equal true, user.valid?
  end

  test 'should return instance with errors if invitation_token is nil' do
    User.create(:email => 'admin@test.com', :password => '123456', :password_confirmation => '123456')
    user = User.accept_invitation!
    assert !user.errors.empty?
  end

  test "should count accepted and not accepted invitations" do
    assert_equal 0, User.invitation_not_accepted.count
    assert_equal 0, User.invitation_accepted.count

    User.invite!(:email => "invalid@email.com")
    user = User.invite!(:email => "valid@email.com")

    assert_equal 2, User.invitation_not_accepted.count
    assert_equal 0, User.invitation_accepted.count

    user.accept_invitation!
    assert_equal 1, User.invitation_not_accepted.count
    assert_equal 1, User.invitation_accepted.count
  end

  test "should preserve return values of Devise::Recoverable#reset_password!" do
    user = new_user
    retval = user.reset_password!('anewpassword', 'anewpassword')
    assert_equal true, retval
  end
end
