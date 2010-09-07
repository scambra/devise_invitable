require 'spec_helper'

describe Devise::Models::Invitable do
  
  describe "Non-disturbance" do
    it "should not generate invitation token after creating a record" do
      Factory(:user).invitation_token.should be_nil
    end
    
    it "should not disable password validations on new record" do
      user = Factory.build(:user, :password => "123")
      user.should_not be_valid
      user.errors[:password].should be_present
    end
    
    it "should not disable password validations on persisted record" do
      user = Factory(:user)
      user.update_attributes(:password => "123")
      user.errors[:password].should be_present
    end
    
    it "should be possible to edit name without entering password" do
      user = Factory(:user)
      user.name = "Jack Daniels"
      user.should be_valid
      user.errors[:password].should_not be_present
      user.save
      user.reload.name.should == "Jack Daniels"
    end
  end
  
  describe "Class Methods" do
    describe ".invite" do
      it "should return a record with no errors" do
        user = User.invite(:email => "valid@email.com")
        user.errors.should be_empty
      end
      
      it "should set invitation_token" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
      end
      
      it "should send invitation email" do
        emails_sent { User.invite(:email => "valid@email.com") }
      end
      
      it "should return a record with no errors, set invitation_token and send invitation email even if user is invalid and Devise.validate_on_invite = false" do
        emails_sent do
          user = User.invite(:email => "valid@email.com", :name => "a"*50)
          user.should be_persisted
          user.invitation_token.should be_present
        end
      end
      
      it "should return a new record with errors, no invitation_token and no email sent if user is invalid and Devise.validate_on_invite = true" do
        emails_not_sent do
          Devise.stub!(:validate_on_invite).and_return(true)
          user = User.invite(:email => "valid@email.com", :name => "a"*50)
          user.should be_new_record
          user.errors[:name].size.should == 1
          user.invitation_token.should be_nil
          Devise.stub!(:validate_on_invite).and_return(false)
        end
      end
      
      it "should set additional accessible attributes" do
        User.invite(:email => "valid@email.com", :name => "John Doe").name.should == "John Doe"
      end
      
      it "should skip confirmation if user is confirmable" do
        User.invite(:email => "valid@email.com").confirmed_at.should be_present
      end
      
      it "should return existing user with errors if email has already been taken" do
        user = Factory(:user)
        invited_user = User.invite(:email => user.email)
        invited_user.should == user
        invited_user.errors[:email].should == ["has already been taken"]
      end
      
      it "should return a new record with errors if email is blank" do
        [nil, ""].each do |email|
          user = User.invite(:email => email)
          user.should be_new_record
          user.errors[:email].should == ["can't be blank"]
        end
      end
      
      it "should return a new record with errors if email is invalid" do
        user = User.invite(:email => "invalid_email")
        user.should be_new_record
        user.errors[:email].should == ["is invalid"]
      end
    end
    
    describe ".accept_invitation"do
      it "should find a user to set his password with a given invitation_token" do
        user = User.invite(:email => "valid@email.com")
        User.accept_invitation(:invitation_token => user.invitation_token).should == user
      end
      
      it "should clear invitation token with a valid password" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user = User.accept_invitation(:invitation_token => user.invitation_token, :password => "123456")
        user.invitation_token.should be_nil
      end
      
      it "should not clear invitation token if no password has been set" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user = User.accept_invitation(:invitation_token => user.invitation_token)
        user.password.should be_blank
        user.invitation_token.should be_present
      end
      
      it "should not clear invitation token with an invalid password" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user = User.accept_invitation(:invitation_token => user.invitation_token, :password => "12")
        user.invitation_token.should be_present
      end
      
      it "should not clear invitation token with any other invalid attributes" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user = User.accept_invitation(:invitation_token => user.invitation_token, :password => "123456", :name => "a"*50)
        user.invitation_token.should be_present
      end
      
      it "should set password from params" do
        user = User.invite(:email => "valid@email.com")
        user = User.accept_invitation(:invitation_token => user.invitation_token, :password => "123456789")
        user.should be_valid_password("123456789")
      end
      
      it "should return a record with errors if user is invalid" do
        user = User.invite(:email => "valid@email.com")
        invited_user = User.accept_invitation(:invitation_token => user.invitation_token, :password => "new_password", :name => "a"*50)
        invited_user.errors.should be_present
      end
      
      it "should not clear invitation token if record is invalid" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user.name = "a"*50
        user.should_not be_valid
        user.encrypted_password.should be_blank
        User.accept_invitation(:invitation_token => user.invitation_token, :password => "123456789")
        user.encrypted_password.should be_blank
        user.invitation_token.should be_present
      end
      
      it "should return a new record with errors if no invitation_token is found" do
        user = User.accept_invitation(:invitation_token => "invalid_token")
        user.should be_new_record
        user.errors[:invitation_token].should == ["is invalid"]
      end
      
      it "should return a new record with errors if invitation_token is blank" do
        [nil, ""].each do |invitation_token|
          user = User.accept_invitation(:invitation_token => invitation_token)
          user.should be_new_record
          user.errors[:invitation_token].should == ["can't be blank"]
        end
      end
      
      it "should return record with errors if invitation_token has expired" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_sent_at = 2.days.ago
        user.save(:validate => false)
        User.stub!(:invite_for).and_return(10.hours)
        invited_user = User.accept_invitation(:invitation_token => user.invitation_token)
        invited_user.should == user
        invited_user.errors[:invitation_token].should == ["is invalid"]
      end
      
      it "should be able to change user\"s email" do
        user = User.invite(:email => "valid@email.com")
        invited_user = User.accept_invitation(:invitation_token => user.invitation_token, :email => "new@email.com", :password => "new_password")
        invited_user.email.should == "new@email.com"
      end
    end
  end
  
  describe "Instance Methods" do
    describe "#invited?" do
      it "should be invited? after invited?" do
        user = Factory.build(:invited_user)
        user.invite
        user.should be_invited
      end
    end
    
    describe "#valid_invitation?" do
      let(:user) { User.invite(:email => "valid@email.com") }
      
      it "should always be a valid invitation if invite_for is nil" do
        Devise.stub!(:invite_for).and_return(nil)
        user.invitation_sent_at = 10.years.ago
        user.reload.should be_valid_invitation
      end
      
      it "should always be a valid invitation if invite_for is 0" do
        Devise.stub!(:invite_for).and_return(0)
        user.invitation_sent_at = 10.years.ago
        user.reload.should be_valid_invitation
      end
      
      it "should be a valid invitation if the date of invitation is between today and the invite_for interval" do
        Devise.stub!(:invite_for).and_return(10.days)
        user.invitation_sent_at = 5.days.ago
        user.reload.should be_valid_invitation
      end
      
      it "should not be a valid invitation if the date of invitation is older than the invite_for interval" do
        Devise.stub!(:invite_for).and_return(10.days)
        user.invitation_sent_at = 15.days.ago
        user.should_not be_valid_invitation
        Devise.stub!(:invite_for).and_return(0)
      end
    end
    
    describe "#invite" do
      it "should return a record with no errors" do
        user = Factory.build(:invited_user)
        user.invite
        user.errors.should be_empty
      end
      
      it "should set invitation_token" do
        user = Factory.build(:invited_user)
        user.invite
        user.invitation_token.should be_present
      end
      
      it "should not set invitation_token for existing user who are not yet invited" do
        user = Factory(:user)
        user.invite
        user.invitation_token.should be_nil
      end
      
      it "should send invitation email" do
        emails_sent { Factory.build(:invited_user).invite }
      end
      
      it "should return a record with no errors, set invitation_token and send invitation email even if user is invalid and Devise.validate_on_invite = false" do
        emails_sent do
          user = Factory.build(:invited_user, :name => "a"*50)
          user.invite
          user.should be_persisted
          user.invitation_token.should be_present
        end
      end
      
      it "should return a new record with errors, an invitation_token and no email sent if user is invalid and Devise.validate_on_invite = true" do
        emails_not_sent do
          Devise.stub!(:validate_on_invite).and_return(true)
          user = Factory.build(:invited_user, :name => "a"*50)
          user.invite
          user.should be_new_record
          user.errors[:name].size.should == 1
          user.invitation_token.should be_nil
          Devise.stub!(:validate_on_invite).and_return(false)
        end
      end
      
      it "should set additional accessible attributes" do
        user = Factory.build(:invited_user, :name => "John Doe")
        user.invite
        user.name.should == "John Doe"
      end
      
      it "should skip confirmation if user is confirmable" do
        user = Factory.build(:invited_user)
        user.invite
        user.confirmed_at.should be_present
      end
      
      it "should set additional accessible attributes" do
        user = Factory.build(:invited_user, :name => "John Doe")
        user.invite
        user.name.should == "John Doe"
      end
      
      it "should generate a new invitation token on each new User#invite with Devise.validate_on_invite = false" do
        Devise.stub!(:validate_on_invite).and_return(false)
        user = User.invite(:email => "valid@email.com")
        5.times do
          old_token = user.invitation_token
          user.invite
          old_token.should_not == user.invitation_token
        end
      end
      
      it "should generate a new invitation token on each new User#invite with Devise.validate_on_invite = true" do
        Devise.stub!(:validate_on_invite).and_return(true)
        user = User.invite(:email => "valid@email.com")
        5.times do
          old_token = user.invitation_token
          user.invite
          old_token.should_not == user.invitation_token
        end
      end
      
      it "should never generate the same invitation token for different users" do
        invitation_tokens = []
        user = User.invite(:email => "valid@email.com")
        10.times do
          user.invite
          token = user.invitation_token
          invitation_tokens.should_not include(token)
          invitation_tokens << token
        end
      end
    end
    
    describe "#accept_invitation" do
      it "should clear invitation token with a valid password" do
        user = User.invite(:email => "valid@email.com")
        user.password = "123456"
        user.invitation_token.should be_present
        user.accept_invitation
        user.invitation_token.should be_nil
      end
      
      it "should not clear invitation token if no password has been set" do
        user = User.invite(:email => "valid@email.com")
        user.invitation_token.should be_present
        user.accept_invitation
        user.encrypted_password.should be_blank
        user.invitation_token.should be_present
      end
      
      it "should not clear invitation token with an invalid password" do
        user = User.invite(:email => "valid@email.com")
        user.password = "12"
        user.invitation_token.should be_present
        user.accept_invitation
        user.invitation_token.should be_present
      end
      
      it "should not clear invitation token with any other invalid attributes" do
        user = User.invite(:email => "valid@email.com")
        user.password = "123456"
        user.name = "a"*50
        user.invitation_token.should be_present
        user.accept_invitation
        user.invitation_token.should be_present
      end
      
      it "should set password with a valid password" do
        user = User.invite(:email => "valid@email.com")
        user.password = "123456"
        user.accept_invitation
        user.encrypted_password.should be_present
      end
    end
  end
  
end