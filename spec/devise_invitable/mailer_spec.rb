require 'spec_helper'

describe Devise::Models::Invitable do
  before(:each) do
    ActionMailer::Base.deliveries.clear
    Devise.mailer_sender = "test@example.com"
    @user = User.invite(:email => "valid@email.com")
  end
  
  subject { @user }
  
  it "email sent after reseting the user password" do
    ActionMailer::Base.deliveries.size.should == 1
  end
  
  it "content type should be set to html" do
    last_delivery.content_type.should == "text/html; charset=UTF-8"
  end
  
  it "send invitation to the user email" do
    last_delivery.to.should == [subject.email]
  end
  
  it "setup sender from configuration" do
    last_delivery.from.should == ["test@example.com"]
  end
  
  it "setup subject from I18n" do
    I18n.locale = :en
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :subject => 'You Got An Invitation!' } } } do
      User.invite(:email => "valid2@email.com")
      last_delivery.subject.should == "You Got An Invitation!"
    end
  end
  
  it "subject namespaced by model" do
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :user_subject => 'You Got An User Invitation!' } } } do
      User.invite(:email => "valid2@email.com")
      last_delivery.subject.should == "You Got An User Invitation!"
    end
  end
  
  it "body should have user info" do
    last_delivery.body.should =~ /#{subject.email}/
  end
  
  it "body should have link to confirm the account" do
    host = ActionMailer::Base.default_url_options[:host]
    invitation_url_regexp = %r{<a href=\"http://#{host}/users/invitation/accept\?invitation_token=#{subject.invitation_token}">}
    last_delivery.body.should =~ invitation_url_regexp
  end
  
  def last_delivery
    ActionMailer::Base.deliveries.last
  end
  
end