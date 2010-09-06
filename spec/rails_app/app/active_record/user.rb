class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable
  
  attr_accessible :email, :name, :password, :password_confirmation
  
  validates :name, :length => { :maximum => 20 }
end