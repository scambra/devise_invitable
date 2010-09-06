require File.dirname(__FILE__) + '/acceptance_helper'

feature "Invitations:" do
  
  scenario "invalid password should still raise errors" do
    user = invite
    sign_out
    accept_invitation :invitation_token => user.invitation_token
    
    visit "/users/edit"
    
    fill_in 'Password', :with => "123"
    fill_in 'Password confirmation', :with => "123"
    fill_in 'Current password', :with => "987654321"
    click_button "Update"
    
    current_url.should == "http://www.example.com/users"
    page.should have_css('#error_explanation')
    page.should have_content("Password is too short (minimum is 6 characters)")
    user.reload.should_not be_valid_password('123')
  end
  
end