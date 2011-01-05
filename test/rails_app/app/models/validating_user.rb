class ValidatingUser < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :invitable, :validatable
  attr_accessible :username, :email, :password, :password_confirmation, :name
  validates :name, :presence => true
end
