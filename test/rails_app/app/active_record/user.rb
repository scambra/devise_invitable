class User < ActiveRecord::Base
  devise :database_authenticatable, :validatable, :confirmable, :invitable
  
  attr_accessible :email, :name, :password, :password_confirmation
  
  validates :name, :length => { :maximum => 20 }
end