class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :recoverable
  
  attr_accessible :email, :username, :password, :password_confirmation, :skip_invitation
  
  validates :username, :length => { :maximum => 20 }
end
