require 'spec_helper'

class Invitable < User
  devise :invitable, :invite_for => 2.weeks, :validate_on_invite => true
end

describe DeviseInvitable do
  
  describe "Invitable" do
    it "should include Devise modules" do
      [:database_authenticatable, :validatable, :confirmable, :invitable].each do |mod|
        Invitable.devise_modules.should include mod
        Invitable.included_modules.should include Devise::Models::const_get(mod.to_s.classify)
      end
    end
    
    it "should not include other Devise modules" do
      (Devise::ALL - [:database_authenticatable, :validatable, :confirmable, :invitable]).each do |mod|
        Invitable.devise_modules.should_not include mod
        Invitable.included_modules.should_not include Devise::Models::const_get(mod.to_s.classify)
      end
    end
    
    it "set a default value for invite_for" do
      User.invite_for.should == 0
    end
    
    it "set a default value for validate_on_invite" do
      User.validate_on_invite.should be_false
    end
    
    it "set a custom value for invite_for" do
      Invitable.invite_for.should == 2.weeks
    end
    
    it "set a custom value for validate_on_invite" do
      Invitable.validate_on_invite.should be_true
    end
    
    it "invitable attributes" do
      Invitable.new.invitation_token.should be_nil
      Invitable.new.invitation_sent_at.should be_nil
    end
  end
  
end