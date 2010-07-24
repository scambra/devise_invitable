module Devise::Schema
  
  # Creates invitation_token and invitation_sent_at columns in the database
  def invitable
    apply_devise_schema :invitation_token,   String,  :limit => 20
    apply_devise_schema :invitation_sent_at, DateTime
  end
  
end