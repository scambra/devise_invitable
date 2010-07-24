require 'test/test_helper'

class InvitableTest < ActiveSupport::TestCase
  
  def setup
    setup_mailer
  end
  
  test 'should not generate invitation token after creating a record' do
    assert_nil new_user.invitation_token
  end
  
  # =================
  # = User#invited? =
  # =================
  test 'should be invited? after invite on User#invited?' do
    user = new_user
    user.invite
    assert user.invited?
  end
  
  # ==========================
  # = User#valid_invitation? =
  # ==========================
  test 'should test invitation_sent_at with invite_for configuration value after invite on User#valid_invitation?' do
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
    user.invitation_sent_at = 2.days.ago
    assert_not user.valid_invitation?
  end
  
  # ===============
  # = User#invite =
  # ===============
  test 'should generate invitation token for new user on User#invite' do
    user = new_user
    user.invite
    assert_not_nil user.invitation_token
  end
  
  test 'should not generate invitation token for existing user who are not yet invited on User#invite' do
    user = create_user
    user.invite
    assert_nil user.invitation_token
  end
  
  test 'should persist new user on User#invite' do
    user = new_user
    user.invite
    assert user.persisted?
  end
  
  test 'should not persist new user if invalid on User#invite' do
    user = new_user
    User.validate_on_invite = true
    user.stubs(:valid?).returns(false)
    assert_not user.persisted?
  end
  
  test 'should skip confirmation if user is confirmable on User#invite' do
    user = new_user
    user.invite
    assert_present user.confirmed_at
  end
  
  test 'should set additional accessible attributes on User#invite' do
    user = new_user(:name => "John Doe")
    user.invite
    assert_equal "John Doe", user.name
  end
  
  test 'should generate a new invitation token on each new User#invite' do
    user = new_user
    3.times do
      token = user.invitation_token
      user.invite
      assert_not_equal token, user.invitation_token
    end
  end
  
  test 'should never generate the same invitation token for different users on User#invite' do
    invitation_tokens = []
    10.times do
      user = new_user
      user.invite
      token = user.invitation_token
      assert invitation_tokens.exclude?(token)
      invitation_tokens << token
    end
  end
  
  test 'should send invitation email on User#invite' do
    assert_email_sent { new_user.invite }
  end
  
  test 'should not send invitation email if user is invalid on User#invite' do
    invited_user = new_user
    User.validate_on_invite = true
    invited_user.stubs(:valid?).returns(false)
    assert_email_not_sent { invited_user.invite }
  end
  
  # ==========================
  # = User#accept_invitation =
  # ==========================
  test 'should clear invitation token on User#accept_invitation' do
    invited_user = create_user_with_invitation('valid_token')
    invited_user.password = '123456'
    assert_present invited_user.invitation_token
    invited_user.accept_invitation
    assert_nil invited_user.invitation_token
  end
  
  test 'should set password on User#accept_invitation' do
    invited_user = create_user_with_invitation('valid_token')
    invited_user.password = '123456'
    invited_user.accept_invitation
    assert_present invited_user.encrypted_password
  end
  
  test 'should not accept invitation if no password has been set on User#accept_invitation' do
    invited_user = create_user_with_invitation('valid_token')
    assert_present invited_user.invitation_token
    invited_user.accept_invitation
    assert_blank invited_user.encrypted_password
    assert_present invited_user.invitation_token
  end
  
  # ===============
  # = User.invite =
  # ===============
  test 'should return a record with no errors on User.invite' do
    user = User.invite(:email => "valid@email.com")
    assert_blank user.errors
  end
  
  test 'should set invitation_token on User.invite' do
    user = User.invite(:email => "valid@email.com")
    user.invite
    assert_present user.invitation_token
  end
  
  test 'should send invitation email on User.invite' do
    user = User.invite(:email => "valid@email.com")
    assert_email_sent { user.invite }
  end
  
  test 'should return a record with no errors, set invitation_token and send invitation email even if user is invalid and User.validate_on_invite = false on User.invite' do
    User.validate_on_invite = false
    user = User.invite(:email => "valid@email.com", :name => "a"*50)
    assert_blank user.errors
    assert_present user.invitation_token
    assert_email_sent { user.invite }
  end
  
  test 'should return a new record with errors, an invitation_token and no email sent if user is invalid and User.validate_on_invite = true on User.invite' do
    User.validate_on_invite = true
    user = User.invite(:email => "valid@email.com", :name => "a"*50)
    assert_present user.errors
    assert_present user.invitation_token
    assert_email_not_sent { user.invite }
  end
  
  test 'should set additional accessible attributes on class User.invite' do
    user = User.invite(:email => "valid@email.com", :name => "John Doe")
    assert_equal "John Doe", user.name
  end
  
  test 'should return existing user with errors if email has already been taken on User.invite' do
    user = create_user
    invited_user = User.invite(:email => user.email)
    assert_equal invited_user, user
    assert_equal ["#{DEVISE_ORM == :mongoid ? 'is already' : 'has already been'} taken"], invited_user.errors[:email]
  end
  
  test 'should return a new record with errors if email is blank on User.invite' do
    user1 = User.invite(:email => nil)
    assert user1.new_record?
    assert_equal ["can't be blank"], user1.errors[:email]
    
    user2 = User.invite(:email => '')
    assert user2.new_record?
    assert_equal ["can't be blank"], user2.errors[:email]
  end
  
  test 'should return a new record with errors if email is invalid on User.invite' do
    user = User.invite(:email => 'invalid_email')
    assert user.new_record?
    assert_equal ["is invalid"], user.errors[:email]
  end
  
  # ==========================
  # = User.accept_invitation =
  # ==========================
  test 'should find a user to set his password with a given invitation_token on User.accept_invitation' do
    user = create_user_with_invitation('valid_token')
    invited_user = User.accept_invitation(:invitation_token => user.invitation_token)
    assert_equal invited_user, user
  end
  
  test 'should set password and password confirmation from params on User.accept_invitation' do
    create_user_with_invitation('valid_token', :password => nil, :password_confirmation => nil)
    user = User.accept_invitation(:invitation_token => 'valid_token', :password => '123456789', :password_confirmation => '123456789')
    assert user.valid_password?('123456789')
  end
  
  test 'should return a record with errors if user is invalid on User.accept_invitation' do
    user = create_user_with_invitation('valid_token')
    
    invited_user = User.accept_invitation(
      :invitation_token => user.invitation_token,
      :password => 'new_password',
      :password_confirmation => 'new_password',
      :name => "a"*50)
    
    assert_present invited_user.errors
  end
  
  test 'should not clear invitation token if record is invalid on User.accept_invitation' do
    user = create_user_with_invitation('valid_token')
    assert_present user.invitation_token
    User.any_instance.stubs(:valid?).returns(false)
    User.accept_invitation(:invitation_token => 'valid_token', :password => '123456789', :password_confirmation => '987654321')
    user.reload
    assert_blank user.encrypted_password
    assert_present user.invitation_token
  end
  
  test 'should return a new record with errors if no invitation_token is found on User.accept_invitation' do
    user = User.accept_invitation(:invitation_token => 'invalid_token')
    assert user.new_record?
    assert_equal ['is invalid'], user.errors[:invitation_token]
  end
  
  test 'should return a new record with errors if invitation_token is blank on User.accept_invitation' do
    user1 = User.accept_invitation(:invitation_token => nil)
    assert user1.new_record?
    assert_equal ["can't be blank"], user1.errors[:invitation_token]
    
    user2 = User.accept_invitation(:invitation_token => '')
    assert user2.new_record?
    assert_equal ["can't be blank"], user2.errors[:invitation_token]
  end
  
  test 'should return record with errors if invitation_token has expired on User.accept_invitation' do
    user = create_user_with_invitation('valid_token')
    user.invitation_sent_at = 2.days.ago
    user.save
    User.stubs(:invite_for).returns(10.hours)
    invited_user = User.accept_invitation(:invitation_token => user.invitation_token)
    assert_equal user, invited_user
    assert_equal ["is invalid"], invited_user.errors[:invitation_token]
  end
  
  test 'should be able to change user\'s email on User.accept_invitation' do
    user = new_user(:password => nil, :password_confirmation => nil)
    user.invite
    
    invited_user = User.accept_invitation(
      :invitation_token => user.invitation_token,
      :email => 'new@email.com',
      :password => 'new_password',
      :password_confirmation => 'new_password')
    
    assert_equal 'new@email.com',  invited_user.email
  end
end