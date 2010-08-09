require File.dirname(__FILE__) + '/acceptance_helper'

feature "Invitations:" do
  background do
    ActionMailer::Base.deliveries.clear
  end
  
  scenario "not authenticated user should not be able to send an invitation" do
    visit "http://www.example.com/users/invitation/new"
    
    current_url.should == "http://www.example.com/users/sign_in"
  end
  
  scenario "authenticated user should be able to send an invitation" do
    invite
    
    current_url.should == "http://www.example.com/"
    page.should have_content('An invitation email has been sent to user@test.com.')
    User.last.email.should == "user@test.com"
    User.last.invitation_token.should be_present
    ActionMailer::Base.deliveries.size.should == 2
  end
  
  scenario "invitation for an already taken email should receive an error message" do
    user = create_user
    invite do
      fill_in 'Email', :with => user.email
    end
    
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css("input[type=text][value='#{user.email}']")
    page.should have_content("Email #{DEVISE_ORM == :mongoid ? 'is already' : 'has already been'} taken")
  end
  
  scenario "invalid record should succeed and thus redirect with validate_on_invite = false" do
    invite do
      fill_in 'Name', :with => "a"*50
      fill_in 'Email', :with => "user@test.com"
    end
    
    current_url.should == "http://www.example.com/"
    page.should have_content('An invitation email has been sent to user@test.com.')
  end
  
  scenario "invalid record should not succeed and thus redirect with validate_on_invite = true" do
    Devise.stub!(:validate_on_invite).and_return(true)
    invite do
      fill_in 'Name', :with => "a"*50
      fill_in 'Email', :with => "user@test.com"
    end
    
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_content("Name is too long")
    Devise.stub!(:validate_on_invite).and_return(false)
  end
  
  scenario "authenticated user should not be able to visit accept invitation page" do
    sign_in_as_user
    visit "http://www.example.com/users/invitation/accept"
    
    current_url.should == "http://www.example.com/"
  end
  
  scenario "not authenticated user with invalid invitation token should not be able to accept invitation" do
    user = create_user
    accept_invitation :invitation_token => 'invalid_token'
    
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css('#error_explanation')
    page.should have_content('Invitation token is invalid')
    user.should_not be_valid_password('987654321')
  end
  
  scenario "not authenticated user with valid invitation token but invalid password should not be able to accept invitation" do
    user = invite
    sign_out
    accept_invitation :invitation_token => user.invitation_token do
      fill_in 'Password confirmation', :with => 'other_password'
    end
    
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css('#error_explanation')
    page.should have_content("Password doesn't match confirmation")
    user.should_not be_valid_password('987654321')
  end
  
  scenario "not authenticated user with valid data should be able to accept invitation" do
    user = invite
    sign_out
    accept_invitation :invitation_token => user.invitation_token
    
    current_url.should == "http://www.example.com/"
    page.should have_content("Your password was set successfully. You are now signed in.")
    user.reload.should be_valid_password('987654321')
    User.last.email.should == "user@test.com"
    User.last.invitation_token.should be_nil
  end
  
  scenario "after entering invalid data user should still be able to accept invitation" do
    user = invite
    sign_out
    accept_invitation :invitation_token => user.invitation_token do
      fill_in 'Password confirmation', :with => 'other_password'
    end
    
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css('#error_explanation')
    page.should have_content("Password doesn't match confirmation")
    user.reload.should_not be_valid_password('987654321')
    
    fill_in 'Password', :with => '12'
    fill_in 'Password confirmation', :with => '12'
    click_button 'Set my password'
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css('#error_explanation')
    page.should have_content('Password is too short (minimum is 6 characters)')
    user.should_not be_valid_password('12')
    
    fill_in 'Password', :with => '1'*21
    fill_in 'Password confirmation', :with => '1'*21
    click_button 'Set my password'
    current_url.should == "http://www.example.com/users/invitation"
    page.should have_css('#error_explanation')
    page.should have_content('Password is too long (maximum is 20 characters)')
    user.should_not be_valid_password('1'*21)
    
    fill_in 'Password', :with => '987654321'
    fill_in 'Password confirmation', :with => '987654321'
    click_button 'Set my password'
    
    current_url.should == "http://www.example.com/"
    page.should have_content("Your password was set successfully. You are now signed in.")
    user.reload.should be_valid_password('987654321')
  end
  
  scenario "sign in user automatically after setting it\'s password" do
    user = invite
    sign_out
    accept_invitation :invitation_token => user.invitation_token
    sign_out
    
    page.should have_content('Signed out successfully.')
  end
  
end